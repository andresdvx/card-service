terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Infraestructura para gestión de la cola SQS y la lambda que procesa los mensajes de la cola para creación de tarjetas DEBITO / CRÉDITO

# -> cola para generación de tarjetas DEBITO / CRÉDITO
resource "aws_sqs_queue" "create-request-card-sqs" {
  name                        = var.sqs_create_request_card
  fifo_queue                  = false
  content_based_deduplication = false
  visibility_timeout_seconds  = 900
  message_retention_seconds   = 1209600 # 14 días
  receive_wait_time_seconds   = 20      # Long polling
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.create-request-card-dlq.arn
    maxReceiveCount     = 3
  })
}

# Dead Letter Queue para mensajes fallidos
resource "aws_sqs_queue" "create-request-card-dlq" {
  name                      = "${var.sqs_create_request_card}-dlq"
  message_retention_seconds = 1209600 # 14 días
}

# -> lambda para procesamiento de la cola de creación de tarjetas
resource "aws_lambda_function" "create-request-card-lambda" {
  filename         = data.archive_file.lambda_sqs_create_card_file.output_path
  function_name    = var.lambda_sqs_create_card
  handler          = var.lambda_sqs_create_card_handler
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_rol_lambda_sqs_create_card.arn
  source_code_hash = data.archive_file.lambda_sqs_create_card_file.output_base64sha256
  publish          = true

  environment {
    variables = {
      DYNAMODB_CARDS_TABLE = aws_dynamodb_table.card-table.name
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_sqs_create_card,
    data.archive_file.lambda_sqs_create_card_file,
    aws_sqs_queue.create-request-card-sqs,
  ]

}

# IAM Role para la lambda de procesamiento de la cola SQS de creación de tarjetas
resource "aws_iam_role" "iam_rol_lambda_sqs_create_card" {
  name               = "iam_rol_lambda_sqs_create_card"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de procesamiento de la cola SQS de creación de tarjetas
resource "aws_iam_role_policy" "iam_policy_lambda_sqs_create_card" {
  name   = "iam_policy_lambda_sqs_create_card"
  role   = aws_iam_role.iam_rol_lambda_sqs_create_card.id
  policy = data.aws_iam_policy_document.lambda_sqs_create_card_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_policy_attachment_lambda_sqs_create_card" {
  role       = aws_iam_role.iam_rol_lambda_sqs_create_card.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Mapeo de la cola SQS a la lambda para que se dispare al llegar mensajes
resource "aws_lambda_event_source_mapping" "sqs_create_card_event_source" {
  event_source_arn                   = aws_sqs_queue.create-request-card-sqs.arn
  function_name                      = aws_lambda_function.create-request-card-lambda.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 0
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  scaling_config {
    maximum_concurrency = 5
  }
}


# tablas dynamoDB


# -> Tabla DynamoDB para almacenar la información de las tarjetas DEBITO / CRÉDITO
resource "aws_dynamodb_table" "card-table" {
  name           = var.dynamodb_table_card
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20

  hash_key = "uuid"

  attribute {
    name = "uuid"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
