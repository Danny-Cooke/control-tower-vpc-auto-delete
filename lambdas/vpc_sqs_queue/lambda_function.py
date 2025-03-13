import os
import json
import boto3

sqs = boto3.client('sqs')
QUEUE_URL = os.environ['SQS_QUEUE_URL']
REGIONS = os.environ.get('REGIONS', '')

def lambda_handler(event, context):
    # ✅ Simply use print(), which AWS Lambda automatically logs to CloudWatch
    print("Received event:", json.dumps(event))
    
    # Extract Account ID from the event
    account_id = event.get('detail', {}).get('requestParameters', {}).get('accountId')
    if not account_id:
        print("No accountId found in event detail.")
        return
    
    # Determine regions to target
    if REGIONS:
        regions_list = [r.strip() for r in REGIONS.split(',') if r.strip()]
    else:
        # Fallback: Get all AWS regions dynamically
        ec2 = boto3.client('ec2')
        regions_resp = ec2.describe_regions()
        regions_list = [r['RegionName'] for r in regions_resp['Regions']]
    
    # Send one message per region
    for region in regions_list:
        message_body = json.dumps({"account_id": account_id, "region": region})
        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=message_body,
            MessageGroupId=str(account_id),  # Maintain FIFO order per account
            MessageDeduplicationId=str(account_id) + "-" + region + "-" + context.aws_request_id  # Ensure uniqueness
        )
        print(f"✅ Enqueued message for Account {account_id}, Region {region}: {response['MessageId']}")
