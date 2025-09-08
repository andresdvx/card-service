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
  visibility_timeout_seconds  = 20
  message_retention_seconds   = 1209600
  receive_wait_time_seconds   = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.create-request-card-dlq.arn
    maxReceiveCount     = 1
  })
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
      DYNAMODB_CARDS_TABLE        = aws_dynamodb_table.card-table.name
      NOTIFICATIONS_EMAIL_SQS_URL = data.aws_sqs_queue.notification-email-sqs.url
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

# Infraestructura para las dlq, colas fallidas

# -> Dead Letter Queue para mensajes fallidos
resource "aws_sqs_queue" "create-request-card-dlq" {
  name                       = "${var.sqs_create_request_card}-dlq"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 960
  receive_wait_time_seconds  = 20
}

# -> Lambda para procesar mensajes fallidos en la DLQ
resource "aws_lambda_function" "card-request-failed" {
  filename         = data.archive_file.lambda_card_request_failed_file.output_path
  function_name    = var.lambda_dlq_request_card_failed
  handler          = var.lambda_dlq_request_card_failed_handler
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_rol_lambda_dql_request_card_failed.arn
  source_code_hash = data.archive_file.lambda_card_request_failed_file.output_base64sha256
  publish          = true

  environment {
    variables = {
      DYNAMODB_FAILED_REQUESTS_TABLE = aws_dynamodb_table.card-table-error.name
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_dql_request_card_failed,
    data.archive_file.lambda_card_request_failed_file,
    aws_sqs_queue.create-request-card-dlq,
  ]
}

# IAM Role para la lambda de procesamiento de la DLQ
resource "aws_iam_role" "iam_rol_lambda_dql_request_card_failed" {
  name               = "iam_rol_lambda_dlq_request_card_failed"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de procesamiento de la DLQ
resource "aws_iam_role_policy" "iam_policy_lambda_dql_request_card_failed" {
  name   = "iam_policy_lambda_dlq_request_card_failed"
  role   = aws_iam_role.iam_rol_lambda_dql_request_card_failed.id
  policy = data.aws_iam_policy_document.lambda_card_request_failed_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_policy_attachement_lambda_dlq_request_card_failed" {
  role       = aws_iam_role.iam_rol_lambda_dql_request_card_failed.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Mapeo de la cola DLQ a la lambda para que se dispare al llegar mensajes
resource "aws_lambda_event_source_mapping" "sqs_dlq_request_card_failed_event_source" {
  event_source_arn                   = aws_sqs_queue.create-request-card-dlq.arn
  function_name                      = aws_lambda_function.card-request-failed.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 0
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  scaling_config {
    maximum_concurrency = 5
  }
}

# -> Tabla DynamoDB para almacenar los errores de procesamiento de tarjetas
resource "aws_dynamodb_table" "card-table-error" {
  name           = var.dynamodb_table_errors
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key = "uuid"

  attribute {
    name = "uuid"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}



# Infraestructura para gestión de compras con tarjetas


resource "aws_dynamodb_table" "card-purchase-table" {
  name           = var.dynamodb_table_card_purchase
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


# Lambda para gestionar compras con tarjetas
resource "aws_lambda_function" "card-purchase-lambda" {
  filename         = data.archive_file.lambda_card_purchase_file.output_path
  function_name    = var.lambda_card_purchase
  handler          = var.lambda_card_purchase_handler
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_rol_lambda_card_purchase.arn
  source_code_hash = data.archive_file.lambda_card_purchase_file.output_base64sha256
  publish          = true

  environment {
    variables = {
      DYNAMODB_TRANSACTION_TABLE = aws_dynamodb_table.card-purchase-table.name
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_card_purchase,
    data.archive_file.lambda_card_purchase_file,
    aws_dynamodb_table.card-purchase-table
  ]

}

# IAM Role para la lambda de gestión de compras con tarjetas
resource "aws_iam_role" "iam_rol_lambda_card_purchase" {
  name               = "iam_rol_lambda_card_purchase"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de gestión de compras con tarjetas
resource "aws_iam_role_policy" "iam_policy_lambda_card_purchase" {
  name   = "iam_policy_lambda_card_purchase"
  role   = aws_iam_role.iam_rol_lambda_card_purchase.id
  policy = data.aws_iam_policy_document.lambda_card_purchase_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_policy_attachment_lambda_card_purchase" {
  role       = aws_iam_role.iam_rol_lambda_card_purchase.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
