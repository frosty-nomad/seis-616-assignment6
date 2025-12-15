import json
import boto3
import os
from datetime import datetime
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Process S3 events from SQS queue.
    Extracts image information and writes metadata to destination bucket.
    """
    
    destination_bucket = os.environ['DESTINATION_BUCKET']
    
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            # Parse the SQS message body (which contains the SNS message)
            message_body = json.loads(record['body'])
            
            # Parse the SNS message (which contains the S3 event)
            sns_message = json.loads(message_body['Message'])
            
            # Process each S3 event record
            for s3_record in sns_message['Records']:
                # Extract S3 bucket and object information
                source_bucket = s3_record['s3']['bucket']['name']
                object_key = unquote_plus(s3_record['s3']['object']['key'])
                object_size = s3_record['s3']['object']['size']
                event_time = s3_record['eventTime']
                
                print(f"Processing: s3://{source_bucket}/{object_key}")
                
                # Get object metadata
                try:
                    response = s3_client.head_object(
                        Bucket=source_bucket,
                        Key=object_key
                    )
                    
                    content_type = response.get('ContentType', 'unknown')
                    last_modified = response.get('LastModified', '').isoformat() if response.get('LastModified') else ''
                    
                except Exception as e:
                    print(f"Error getting object metadata: {str(e)}")
                    content_type = 'unknown'
                    last_modified = ''
                
                # Create processing result
                result = {
                    'source_bucket': source_bucket,
                    'object_key': object_key,
                    'object_size': object_size,
                    'content_type': content_type,
                    'event_time': event_time,
                    'last_modified': last_modified,
                    'processed_at': datetime.utcnow().isoformat(),
                    'status': 'processed'
                }
                
                # Generate result file name
                timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S-%f')
                result_key = f"processed/{timestamp}-{object_key.replace('/', '_')}.json"
                
                # Store result in destination bucket
                s3_client.put_object(
                    Bucket=destination_bucket,
                    Key=result_key,
                    Body=json.dumps(result, indent=2),
                    ContentType='application/json'
                )
                
                print(f"Result stored: s3://{destination_bucket}/{result_key}")
                processed_count += 1
                
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            print(f"Record: {json.dumps(record)}")
            failed_count += 1
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed_count,
            'failed': failed_count
        })
    }
