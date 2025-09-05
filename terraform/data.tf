# Terraform Data Source for Lambda SQS Create Card File
data "archive_file" "lambda_sqs_create_card_file" {
  type        = "zip"
  source_file = "${path.module}./app/dist/create-request-card-lambda.js"
  output_path = "lambda_create-request-card-lambda.zip"
}

# IAM Role Policy Document for Lambda Assume Role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role Policy Document for Lambda SQS Create Card Execution
data "aws_iam_policy_document" "lambda_sqs_create_card_execution" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]
    resources = [
      aws_sqs_queue.create-request-card-sqs.arn
    ]
  }
}
