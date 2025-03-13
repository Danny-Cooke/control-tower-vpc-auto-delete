# DEFAULT VPC AUTOMATED REMOVAL
## Overview

This project leverages Terraform to automate the deletion of default VPCs in unmanaged AWS regions. It provides a robust solution for organizations using AWS Control Tower, ensuring best practices and maintaining optimal security across AWS multi-account environments.

## Purpose

Designed for organizations that:

- Use multi-account structures on AWS
- Manage AWS accounts and governance through AWS Control Tower
- Prioritize security best practices and efficient resource management

## Problem

When provisioning new AWS accounts, AWS Control Tower automatically creates a default VPC in every region with internet access, including unused regions. AWS advises removing these unnecessary default VPCs to enhance security and reduce attack surfaces. However:

- AWS Control Tower deletes default VPCs only in managed regions.
- Default VPCs remain in unmanaged regions, posing potential security risks.
- Manual deletion of VPCs in unmanaged regions is complex and challenging.

## Solution

This solution automatically deletes default VPCs in unmanaged AWS regions by:

- Detecting account movement from the root Organizational Unit (OU) to any sub-OU via CloudTrail.
- Triggering a Lambda function to enqueue account details for each AWS region into an SQS FIFO queue.
- Executing a secondary Lambda function to assume the `AWSControlTowerExecution` role, accessing locked-down regions, and deleting unnecessary default VPCs.

## Architecture

The infrastructure comprises the following components:

- **SQS Queues:** Handle asynchronous, reliable processing of deletion events.
- **IAM Roles & Policies:** Provide secure access and required permissions to Lambda functions.
- **CloudWatch Event Rules:** Capture CloudTrail events for real-time monitoring and triggering Lambda processes.
- **S3 Buckets:** Durable storage for logs and operational data.
- **Lambda Functions:** Implement business logic for event processing and VPC deletion.

### Workflow

1. **Event Detection:** CloudWatch captures CloudTrail events when accounts move between OUs.
2. **Queueing Messages:** `vpc_sqs_queue` Lambda enqueues messages for each AWS region.
3. **VPC Deletion:** `vpc_delete` Lambda consumes messages, assumes the necessary roles, and deletes default VPCs.
4. **Logging & Monitoring:** Logs stored in S3 with monitoring and alerts via CloudWatch.

---

## Getting Started

### Prerequisites

- [Terraform v1.5+](https://www.terraform.io/downloads.html)
- AWS account with sufficient privileges
- AWS CLI configured with credential
- AWS S3 bucket precreated to house the state storage  

### Installation
The below basic instructions deploy with minimal custom configuration. This includes deploying the pre-Zipped lambda functions that have already been prepared in this repository. However, if changes are required or you just prefer to add the zip files yourself, go to the "Lambda Preparation" section first and then return here. 

1. **Clone the repository**:

```bash
git clone git@github.com:Danny-Cooke/control-tower-vpc-auto-delete.git
cd root-account
```

2. **Configure Terraform files**:

- Update `provider.tf` with your AWS credentials or (recommended) role-based authentication.
- Configure `backend.tf` for Terraform state storage.
- Customize variables in `main.tf`, including the `project_name` and `root_ou` (OU ID).

3. **Initialize Terraform**:

```bash
terraform init
```

4. **Deploy infrastructure**:

```bash
terraform apply
```

---

### Lambda Preparation
Using gitbash inside VSCODE 

```bash
cd lambdas/vpc_delete
pip install boto3 -t ./package
pip install botocore -t ./package
cd ../vpc_sqs_queue
pip install boto3 -t ./package
pip install botocore -t ./package
```

Navigate into each of the folders where the function is visable and the package directory is also visable. Create a zip file containing the function and the package folder. Replace the Zip files in the zips folder with these 2 new zips. 

## Project Structure

```
root-account/
├── backend.tf          # Terraform state backend configuration
├── provider.tf         # AWS provider configuration
├── main.tf             # Main infrastructure definitions
├── lambdas/            # Lambda function code
└── .gitignore          # Git ignore rules
```

---

## Components Explained

### SQS Queues
Decouples event handling to ensure reliable asynchronous processing, scalability, and ordered message consumption.

### IAM Roles & Policies
Ensures secure interactions between AWS services, specifically tailored for Lambda functions to execute their responsibilities safely.

### CloudWatch Event Rules
Trigger Lambdas based on CloudTrail events, enabling real-time automated responses.

### S3 Buckets
Provides durable storage for logs and operational data to aid in auditing and troubleshooting.

### Lambda Functions
- **`vpc_sqs_queue`**: Enqueues messages detailing accounts and regions.
- **`vpc_delete`**: Processes messages, assumes necessary roles, and deletes VPCs in specified regions.

### Environment Variables
Lambda functions require:
- `SQS_QUEUE_URL`: URL for the SQS queue.

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new feature branch: `git checkout -b feature-name`.
3. Commit your changes: `git commit -m 'Detailed description of changes'`.
4. Push your branch: `git push origin feature-name`.
5. Open a Pull Request.

---

## License

Distributed under the MIT License.

---

## Author

- **Danny Cooke**

---

## Acknowledgments

Thanks to [makeareadme.com](https://www.makeareadme.com/) for providing inspiration for the README structure.

