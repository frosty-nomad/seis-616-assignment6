# SEIS-616 Assignment 6 - SQS Fan Out

This Terraform template creates an event-driven AWS architecture that automatically processes images uploaded to S3. When an image is uploaded to the source S3 bucket, it triggers an event notification to an SNS topic, which fans out to an SQS queue. The SQS queue triggers a Lambda function that extracts image metadata and stores the results as JSON files in a destination S3 bucket.

## Architecture Flow

**S3 (source)** → **SNS Topic** → **SQS Queue** → **Lambda Function** → **S3 (destination)**