import boto3
import botocore
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)  # ✅ AWS Lambda automatically logs to CloudWatch

TARGET_ROLE_NAME = "AWSControlTowerExecution"

def assume_role(account_id):
    """Assume IAM role in the target account and return temporary credentials."""
    sts_client = boto3.client('sts')
    role_arn = f"arn:aws:iam::{account_id}:role/{TARGET_ROLE_NAME}"
    try:
        response = sts_client.assume_role(RoleArn=role_arn, RoleSessionName="DeleteDefaultVPCSession")
        creds = response['Credentials']
        logger.info(f"Assumed role {role_arn} successfully.")
        return creds
    except Exception as e:
        logger.error(f"Failed to assume role {role_arn}: {e}", exc_info=True)
        raise

def delete_default_vpc(account_id, region, ec2_client):
    """Deletes the default VPC and associated resources in a given region."""
    
    # Identify the default VPC
    try:
        vpc_response = ec2_client.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])
        vpcs = vpc_response.get("Vpcs", [])
    except botocore.exceptions.ClientError as e:
        logger.error(f"Error describing VPCs in {region}: {e}", exc_info=True)
        return

    if not vpcs:
        logger.info(f"No default VPC found in region {region}. Nothing to delete.")
        return

    vpc_id = vpcs[0]["VpcId"]
    logger.info(f"Default VPC in {region} is {vpc_id}. Beginning deletion.")

    # Delete subnets
    subnets = ec2_client.describe_subnets(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]).get("Subnets", [])
    for subnet in subnets:
        ec2_client.delete_subnet(SubnetId=subnet["SubnetId"])
        logger.info(f"Deleted subnet {subnet['SubnetId']}")

    # Delete Internet Gateways
    igws = ec2_client.describe_internet_gateways(Filters=[{"Name": "attachment.vpc-id", "Values": [vpc_id]}]).get("InternetGateways", [])
    for igw in igws:
        ec2_client.detach_internet_gateway(InternetGatewayId=igw["InternetGatewayId"], VpcId=vpc_id)
        ec2_client.delete_internet_gateway(InternetGatewayId=igw["InternetGatewayId"])
        logger.info(f"Deleted Internet Gateway {igw['InternetGatewayId']}")

    # Delete VPC
    ec2_client.delete_vpc(VpcId=vpc_id)
    logger.info(f"Deleted VPC {vpc_id} in region {region}")

def lambda_handler(event, context):
    """Lambda function triggered by SQS message to delete default VPC in the specified account and region."""
    try:
        for record in event['Records']:  # Extract messages from SQS
            body = json.loads(record['body'])  # Extract actual JSON message

            account_id = body.get("account_id")  # Extract account_id
            region = body.get("region")  # Extract region

            if not account_id or not region:
                logger.error("Missing required parameters 'account_id' or 'region' in event message.")
                continue  # Skip this message and process the next one
            
            logger.info(f"Processing Account {account_id}, Region {region}")

            # Assume role in target account
            creds = assume_role(account_id)
            ec2_client = boto3.client('ec2', region_name=region,
                                      aws_access_key_id=creds['AccessKeyId'],
                                      aws_secret_access_key=creds['SecretAccessKey'],
                                      aws_session_token=creds['SessionToken'])

            # Delete the default VPC
            delete_default_vpc(account_id, region, ec2_client)
    
    except Exception as e:
        logger.error(f"Error processing event: {e}", exc_info=True)
        return {"status": "error", "message": str(e)}

    return {"status": "success"}
