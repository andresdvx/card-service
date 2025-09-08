# Terraform Data Source for Lambda SQS Create Card File
data "archive_file" "lambda_sqs_create_card_file" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/create-request-card-lambda.js"
  output_path = "lambda_create-request-card-lambda.zip"
}

# Terraform Data Source for Lambda Card Request Failed File
data "archive_file" "lambda_card_request_failed_file" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/card-request-failed-lambda.js"
  output_path = "lambda_card-request-failed-lambda.zip"
}

data "archive_file" "lambda_card_purchase_file" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/card-purchase-lambda.js"
  output_path = "lambda_card-purchase-lambda.zip"
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

  statement { # Permitir a la lambda interactuar con la cola SQS
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl"
    ]
    resources = [
      aws_sqs_queue.create-request-card-sqs.arn,
      data.aws_sqs_queue.notification-email-sqs.arn
    ]
  }

  statement { # Permitir a la lambda escribir en la tabla DynamoDB de tarjetas
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.card-table.arn
    ]
  }
}

# IAM Role Policy Document for Lambda Card Request Failed Execution
data "aws_iam_policy_document" "lambda_card_request_failed_execution" {

  statement { # Permitir a la lambda interactuar con la cola DLQ
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl"
    ]
    resources = [
      aws_sqs_queue.create-request-card-dlq.arn
    ]
  }

  statement { # Permitir a la lambda escribir en la tabla DynamoDB de errores
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.card-table-error.arn
    ]
  }

  statement { # Permitir logs de CloudWatch
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

}

# Data Source para obtener la sqs existente
data "aws_sqs_queue" "notification-email-sqs" {
  name = "inferno-bank-notification-email-sqs-dev" #notification-email-sqs
}


# IAM Role Policy Document for Lambda Card Purchase Execution
data "aws_iam_policy_document" "lambda_card_purchase_execution" {

  statement { # Permitir a la lambda escribir en la tabla DynamoDB de compras con tarjeta
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.card-purchase-table.arn
    ]
  }
}