terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Source S3 bucket for uploading pictures
resource "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket_name
}

# Destination S3 bucket for processed results
resource "aws_s3_bucket" "destination_bucket" {
  bucket = var.destination_bucket_name
}

# SNS Topic
resource "aws_sns_topic" "s3_events" {
  name = "s3-events-topic"
}

# SNS Topic Policy to allow S3 to publish
resource "aws_sns_topic_policy" "s3_events_policy" {
  arn = aws_sns_topic.s3_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.s3_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.source_bucket.arn
          }
        }
      }
    ]
  })
}

# S3 Bucket Notification to SNS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*"]
    filter_suffix = ".png"
  }

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpeg"
  }

  depends_on = [aws_sns_topic_policy.s3_events_policy]
}

# SQS Queue
resource "aws_sqs_queue" "image_processing_queue" {
  name                       = "image-processing-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.image_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.image_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.s3_events.arn
          }
        }
      }
    ]
  })
}

# SNS Subscription to SQS
resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.s3_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.image_processing_queue.arn
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "image-processing-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "image-processing-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.image_processing_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.source_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.destination_bucket.arn}/*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/scan_metadata.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "image-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "scan_metadata.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.destination_bucket.id
    }
  }
}

# Lambda SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_processing_queue.arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 10
  enabled          = true
}
