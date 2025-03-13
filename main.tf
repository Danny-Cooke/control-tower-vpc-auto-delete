locals {
  project_name                = "vpc-deletion"
  root_ou                     = "<OU_ID>"
}

resource "aws_sqs_queue" "vpc_queue" {
  name                        = "${local.project_name}-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true  
  visibility_timeout_seconds = 120
}

resource "aws_iam_role" "lambda_execution_role" {
  name     = "${local.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name     = "${local.project_name}-lambda-policy"
  role     = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:*",
          "ec2:*",
          "events:*",
          "cloudtrail:*",
          "lambda:*",
          "sts:AssumeRole",
          "logs:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = "arn:aws:iam::*:role/AWSControlTowerExecution"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "vpc_event_rule" {
  name           = "${local.project_name}-event-rule"
  description    = "Trigger Lambda on specific AWS Organizations events"

  event_pattern = jsonencode({
    source: ["aws.organizations"],
    "detail-type": ["AWS API Call via CloudTrail"],
    detail: {
      eventSource: ["organizations.amazonaws.com"],
      eventName: ["MoveAccount"],
      requestParameters: {
        sourceParentId: ["${local.root_ou}"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule          = aws_cloudwatch_event_rule.vpc_event_rule.name
  target_id     = aws_lambda_function.lambda_function1.function_name
  arn           = aws_lambda_function.lambda_function1.arn             
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function1.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.vpc_event_rule.arn
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket            = "${local.project_name}-lambda-staging-bucket"
  acl               = "private"
}

resource "aws_s3_bucket_object" "lambda_code" {
  bucket          = aws_s3_bucket.lambda_code_bucket.bucket  
  key             = "lambdas/zips/vpc_sqs_queue.zip"                
  source          = "lambdas/zips/vpc_sqs_queue.zip"     
  acl             = "private"
  etag            = filemd5("lambdas/zips/vpc_sqs_queue.zip")  
  depends_on = [aws_s3_bucket.lambda_code_bucket]
}

resource "aws_s3_bucket_object" "lambda_code2" {
  bucket          = aws_s3_bucket.lambda_code_bucket.bucket  
  key             = "lambdas/zips/vpc_delete.zip"                
  source          = "lambdas/zips/vpc_delete.zip"     
  acl             = "private"
  etag            = filemd5("lambdas/zips/vpc_delete.zip") 
  depends_on = [aws_s3_bucket.lambda_code_bucket] 
}

resource "aws_lambda_function" "lambda_function1" {
  function_name = "${local.project_name}-sqs-queue-message-poster"
  s3_bucket     = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key        = "lambdas/zips/vpc_sqs_queue.zip"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.9"  
  timeout       = 60
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.vpc_queue.id  
    }
  }
}

resource "aws_lambda_function" "lambda_function2" {
  function_name = "${local.project_name}-execution-script"
  s3_bucket     = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key        = "lambdas/zips/vpc_delete.zip"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.9"
  timeout       = 60
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn  = aws_sqs_queue.vpc_queue.arn
  function_name     = aws_lambda_function.lambda_function2.arn
  enabled           = true
}

resource "aws_cloudwatch_log_group" "lambda1_logs" {
  name              = "/aws/lambda/vpc_deletion_sqs_queue_lambda"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda2_logs" {
  name              = "/aws/lambda/vpc_deletion_script_lambda"
  retention_in_days = 30
}
