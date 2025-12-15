variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "source_bucket_name" {
  description = "Name of the S3 bucket for uploading pictures"
  type        = string
}

variable "destination_bucket_name" {
  description = "Name of the S3 bucket for storing processed results"
  type        = string
}
