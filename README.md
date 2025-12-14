# S3-SNS-SQS-Lambda Terraform Project

## Overview

This project demonstrates a complete serverless event-driven architecture on AWS using Terraform. It implements an automated workflow where files uploaded to an S3 bucket trigger a cascade of events through SNS (Simple Notification Service) and SQS (Simple Queue Service), ultimately invoking a Lambda function for processing.

This is an assignment for SEIS 616 focusing on Infrastructure as Code (IaC) practices using Terraform.

## Architecture

```
┌──────────────────┐
│   S3 Bucket      │
│  (File Upload)   │
└────────┬─────────┘
         │
         │ (S3:ObjectCreated:*)
         ▼
┌──────────────────┐
│   SNS Topic      │
│   (Notification) │
└────────┬─────────┘
         │
         │ (Publish)
         ▼
┌──────────────────┐
│   SQS Queue      │
│   (Message Buffer)
└────────┬─────────┘
         │
         │ (Poll Messages)
         ▼
┌──────────────────┐
│  Lambda Function │
│  (Processing)    │
└──────────────────┘
```

## Project Components

### 1. **S3 Bucket**
- Stores uploaded files that trigger the event chain
- Configured with versioning and encryption
- Sends notifications on object creation events

### 2. **SNS Topic**
- Receives file upload notifications from S3
- Acts as a pub/sub messaging service
- Decouples S3 from downstream processing

### 3. **SQS Queue**
- Subscribes to the SNS topic
- Provides reliable message queuing
- Acts as a buffer between notifications and Lambda processing
- Ensures fault tolerance and retry capabilities

### 4. **Lambda Function**
- Processes messages from the SQS queue
- Performs file processing logic
- Logs execution and handles errors
- Scales automatically based on message volume

## Prerequisites

- **Terraform** >= 1.0
- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials
- **Python 3.9+** (for Lambda function development)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/frosty-nomad/seis-616-assignment6.git
cd seis-616-assignment6
```

### 2. Initialize Terraform

```bash
terraform init
```

This command:
- Downloads required providers (AWS)
- Initializes the Terraform working directory
- Sets up the backend configuration

### 3. Validate Configuration

```bash
terraform validate
```

Ensures all Terraform files are syntactically valid.

### 4. Plan Deployment

```bash
terraform plan -out=tfplan
```

This generates an execution plan showing:
- Resources to be created
- Configuration changes
- Dependencies between resources

### 5. Apply Configuration

```bash
terraform apply tfplan
```

Deploys all resources to your AWS account.

### 6. Verify Deployment

```bash
# List created resources
aws s3api list-buckets
aws sns list-topics
aws sqs list-queues
aws lambda list-functions
```

## File Structure

```
seis-616-assignment6/
├── README.md                 # This file
├── main.tf                   # Primary Terraform configuration
├── variables.tf              # Input variables and defaults
├── outputs.tf                # Output values
├── s3.tf                      # S3 bucket configuration
├── sns.tf                     # SNS topic configuration
├── sqs.tf                     # SQS queue configuration
├── lambda.tf                  # Lambda function configuration
├── iam.tf                     # IAM roles and policies
├── lambda_function/
│   └── index.py              # Lambda handler code
├── terraform.tfvars          # Variable assignments (sensitive data)
└── .gitignore                # Git ignore rules
```

## Configuration Variables

Key variables that can be customized:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region for resources |
| `project_name` | string | `seis-616` | Project identifier |
| `environment` | string | `dev` | Deployment environment |
| `s3_bucket_name` | string | `seis616-bucket-{random}` | S3 bucket name |
| `lambda_timeout` | number | `60` | Lambda timeout in seconds |
| `sqs_message_retention` | number | `1209600` | Message retention (14 days) |

## Usage

### Upload a File to S3

```bash
# Upload a file to trigger the event chain
aws s3 cp ./sample-file.txt s3://YOUR_BUCKET_NAME/
```

This will:
1. Create an object in S3
2. Trigger an S3 event notification
3. Publish a message to SNS
4. Deliver the message to SQS
5. Invoke the Lambda function
6. Process the file

### Monitor Execution

```bash
# View Lambda logs
aws logs tail /aws/lambda/seis616-processor --follow

# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url YOUR_QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages

# View SNS topic metrics
aws sns get-topic-attributes \
  --topic-arn YOUR_TOPIC_ARN \
  --attribute-names All
```

### Test Locally

```bash
# Simulate Lambda execution locally
cd lambda_function
python index.py
```

## Lambda Function Details

The Lambda function (`lambda_function/index.py`):
- **Trigger**: SQS messages
- **Runtime**: Python 3.9+
- **Memory**: 256 MB (configurable)
- **Timeout**: 60 seconds (configurable)
- **Responsibilities**:
  - Parse SQS messages
  - Extract S3 bucket and object key
  - Download and process files
  - Log processing results
  - Handle errors gracefully

### Sample Lambda Event

```json
{
  "Records": [
    {
      "messageId": "12345-67890",
      "receiptHandle": "MessageReceiptHandle",
      "body": "{\"Records\": [{\"s3\": {\"bucket\": {\"name\": \"my-bucket\"}, \"object\": {\"key\": \"file.txt\"}}}]}",
      "attributes": {
        "ApproximateReceiveCount": "1",
        "SentTimestamp": "1234567890"
      }
    }
  ]
}
```

## IAM Permissions

The following IAM permissions are automatically created:

### S3 Permissions
- `s3:GetObject` - Read files from bucket
- `s3:ListBucket` - List bucket contents

### SNS Permissions
- `sns:Publish` - Publish messages to topic

### SQS Permissions
- `sqs:SendMessage` - Receive messages from queue
- `sqs:DeleteMessage` - Mark messages as processed
- `sqs:ChangeMessageVisibility` - Adjust visibility timeout

### Lambda Permissions
- `lambda:InvokeFunction` - Allow SQS to invoke Lambda
- `logs:CreateLogGroup` - Create CloudWatch log groups
- `logs:CreateLogStream` - Create log streams
- `logs:PutLogEvents` - Write log events

## Outputs

After deployment, Terraform outputs:

```
s3_bucket_name = "seis616-bucket-abc123"
sns_topic_arn = "arn:aws:sns:us-east-1:123456789:seis616-topic"
sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789/seis616-queue"
sqs_queue_arn = "arn:aws:sqs:us-east-1:123456789:seis616-queue"
lambda_function_name = "seis616-processor"
lambda_function_arn = "arn:aws:lambda:us-east-1:123456789:function:seis616-processor"
```

## Cleanup

To remove all resources and avoid unnecessary AWS charges:

```bash
terraform destroy
```

This will:
- Delete the S3 bucket (if empty)
- Delete the SNS topic
- Delete the SQS queue
- Delete the Lambda function
- Remove all IAM roles and policies

**Warning**: This is a destructive operation. Ensure you've backed up any important data.

## Cost Considerations

### Estimated Monthly Costs (US East 1)
- **S3**: $0.023 per GB stored
- **SNS**: $0.50 per million requests
- **SQS**: $0.40 per million requests
- **Lambda**: Free tier includes 1M requests and 400,000 GB-seconds

### Cost Optimization
- Use S3 lifecycle policies to archive old files
- Set SQS message retention to minimum needed
- Configure Lambda memory to minimize execution time
- Use S3 Intelligent-Tiering for variable access patterns

## Troubleshooting

### Issue: Lambda function not triggered

**Solution**:
1. Verify S3 bucket has event notifications enabled
2. Check SNS topic has SQS queue subscription
3. Confirm SQS queue has Lambda as event source
4. Review CloudWatch logs for errors

### Issue: Messages stuck in SQS queue

**Solution**:
1. Check Lambda function logs for processing errors
2. Verify Lambda has appropriate IAM permissions
3. Increase Lambda timeout if processing takes longer
4. Monitor SQS dead-letter queue for problematic messages

### Issue: Terraform apply fails

**Solution**:
1. Run `terraform validate` to check syntax
2. Ensure AWS credentials are configured
3. Check for resource naming conflicts
4. Verify AWS account has required permissions

## Security Best Practices

1. **Encryption**: Enable encryption at rest for S3, SNS, and SQS
2. **Access Control**: Use IAM policies with least privilege principle
3. **Logging**: Enable CloudTrail for audit logging
4. **Monitoring**: Set up CloudWatch alarms for anomalies
5. **Secrets Management**: Use AWS Secrets Manager for sensitive data
6. **VPC**: Consider deploying Lambda in VPC for additional isolation

## Monitoring and Logging

### CloudWatch Metrics
- S3: Upload requests, bucket size
- SNS: Messages published, delivery failures
- SQS: Messages available, messages in flight
- Lambda: Invocations, errors, duration

### CloudWatch Logs
- Lambda function execution logs
- SNS delivery status
- SQS message processing

### Create Alarms

```bash
# Alarm for Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name seis616-lambda-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

## Contributing

To contribute to this project:

1. Create a feature branch
2. Make your changes
3. Test thoroughly with `terraform plan`
4. Submit a pull request with a clear description

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices)

## License

This project is part of SEIS 616 coursework. Use according to your institution's guidelines.

## Contact

For questions or issues related to this assignment, please contact your course instructor or create an issue in this repository.

---

**Last Updated**: 2025-12-14  
**Author**: frosty-nomad  
**Version**: 1.0.0
