output "source_bucket_name" {
  description = "Name of the source S3 bucket"
  value       = aws_s3_bucket.source_bucket.id
}

output "destination_bucket_name" {
  description = "Name of the destination S3 bucket"
  value       = aws_s3_bucket.destination_bucket.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.s3_events.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.image_processing_queue.url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.image_processor.function_name
}
