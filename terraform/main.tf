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


resource "aws_dynamodb_table" "transaction-table" {
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
      DYNAMODB_CARDS_TABLE        = aws_dynamodb_table.card-table.name
      DYNAMODB_TRANSACTION_TABLE  = aws_dynamodb_table.transaction-table.name
      NOTIFICATIONS_EMAIL_SQS_URL = data.aws_sqs_queue.notification-email-sqs.url
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_card_purchase,
    data.archive_file.lambda_card_purchase_file,
    aws_dynamodb_table.card-table,
    aws_dynamodb_table.transaction-table
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


# -> Lambda para agregar saldo a una tarjeta
resource "aws_lambda_function" "card-transaction-save-lambda" {
  filename         = data.archive_file.lambda_card_transaction_save_file.output_path
  function_name    = var.lambda_card_transaction_save
  handler          = var.lambda_card_transaction_save_handler
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_rol_lambda_card_transaction_save.arn
  source_code_hash = data.archive_file.lambda_card_transaction_save_file.output_base64sha256
  publish          = true


  environment {
    variables = {
      DYNAMODB_CARDS_TABLE        = aws_dynamodb_table.card-table.name
      DYNAMODB_TRANSACTION_TABLE  = aws_dynamodb_table.transaction-table.name
      NOTIFICATIONS_EMAIL_SQS_URL = data.aws_sqs_queue.notification-email-sqs.url
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_card_transaction_save,
    data.archive_file.lambda_card_transaction_save_file,
    aws_dynamodb_table.card-table,
    aws_dynamodb_table.transaction-table
  ]
}

# IAM Role para la lambda de agregar saldo a una tarjeta
resource "aws_iam_role" "iam_rol_lambda_card_transaction_save" {
  name               = "iam_rol_lambda_card_transaction_save"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de agregar saldo a una tarjeta
resource "aws_iam_role_policy" "iam_policy_lambda_card_transaction_save" {
  name   = "iam_policy_lambda_card_transaction_save"
  role   = aws_iam_role.iam_rol_lambda_card_transaction_save.id
  policy = data.aws_iam_policy_document.lambda_card_transaction_save_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_policy_attachment_lambda_card_transaction_save" {
  role       = aws_iam_role.iam_rol_lambda_card_transaction_save.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# -> Lambda para procesar pagos de cupo usado de la tarjeta
resource "aws_lambda_function" "card-paid-credit-card-lambda" {
  filename         = data.archive_file.lambda_card_paid_credit_card_file.output_path
  function_name    = var.lambda_card_paid_credit_card
  handler          = var.lambda_card_paid_credit_card_handler
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_rol_lambda_card_paid_credit_card.arn
  source_code_hash = data.archive_file.lambda_card_paid_credit_card_file.output_base64sha256
  publish          = true

  environment {
    variables = {
      DYNAMODB_TRANSACTION_TABLE  = aws_dynamodb_table.transaction-table.name
      DYNAMODB_CARDS_TABLE        = aws_dynamodb_table.card-table.name
      NOTIFICATIONS_EMAIL_SQS_URL = data.aws_sqs_queue.notification-email-sqs.url
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_card_paid_credit_card_lambda,
    data.archive_file.lambda_card_paid_credit_card_file,
    aws_dynamodb_table.transaction-table
  ]
}

# IAM Role para la lambda de procesar pagos de cupo usado de la tarjeta
resource "aws_iam_role" "iam_rol_lambda_card_paid_credit_card" {
  name               = "iam_rol_lambda_card_paid_credit_card"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de procesar pagos de cupo usado de la tarjeta
resource "aws_iam_role_policy" "iam_policy_card_paid_credit_card_lambda" {
  name   = "iam_policy_card_paid_credit_card_lambda"
  role   = aws_iam_role.iam_rol_lambda_card_paid_credit_card.id
  policy = data.aws_iam_policy_document.lambda_card_paid_credit_card_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_rol_lambda_card_paid_credit_card" {
  role       = aws_iam_role.iam_rol_lambda_card_paid_credit_card.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "card-activate-lambda" {
  filename      = data.archive_file.lambda_card_activate_file.output_path
  function_name = var.lambda_card_activate
  handler       = var.lambda_card_activate_handler
  runtime       = "nodejs22.x"
  timeout       = 900
  memory_size   = 256
  role = aws_iam_role.iam_rol_lambda_card_activate.arn
  source_code_hash = data.archive_file.lambda_card_activate_file.output_base64sha256
  publish       = true

  environment {
    variables = {
      DYNAMODB_TRANSACTION_TABLE  = aws_dynamodb_table.transaction-table.name
      DYNAMODB_CARDS_TABLE        = aws_dynamodb_table.card-table.name
      NOTIFICATIONS_EMAIL_SQS_URL = data.aws_sqs_queue.notification-email-sqs.url
    }
  }

  depends_on = [
    aws_iam_role_policy.iam_policy_lambda_card_activate,
    data.archive_file.lambda_card_activate_file,
    aws_dynamodb_table.card-table,
    aws_dynamodb_table.transaction-table
  ]
}

# IAM Role para la lambda de activar una tarjeta
resource "aws_iam_role" "iam_rol_lambda_card_activate" {
  name               = "iam_rol_lambda_card_activate"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM Policy para la lambda de activar una tarjeta
resource "aws_iam_role_policy" "iam_policy_lambda_card_activate" {
  name   = "iam_policy_lambda_card_activate"
  role   = aws_iam_role.iam_rol_lambda_card_activate.id
  policy = data.aws_iam_policy_document.lambda_card_activate_execution.json
}

# Adjuntar la política gestionada AWSLambdaBasicExecutionRole a la IAM Role de la lambda
resource "aws_iam_role_policy_attachment" "iam_rol_lambda_card_activate" {
  role       = aws_iam_role.iam_rol_lambda_card_activate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API GATEWAY CONFIGURATION

# API Gateway REST API
resource "aws_api_gateway_rest_api" "inferno-bank-api-gateway" {
  name        = var.api_gateway_name
  description = "API Gateway for Card Service"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource: /transactions
resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.root_resource_id
  path_part   = "transactions"
}

# API Gateway Resource: /transactions/purchase
resource "aws_api_gateway_resource" "purchase" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.transactions.id
  path_part   = "purchase"
}

# API Gateway Method: POST /transactions/purchase
resource "aws_api_gateway_method" "purchase_post" {
  rest_api_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id   = aws_api_gateway_resource.purchase.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration: Lambda
resource "aws_api_gateway_integration" "purchase_lambda" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id = aws_api_gateway_resource.purchase.id
  http_method = aws_api_gateway_method.purchase_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.card-purchase-lambda.invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda_purchase" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.card-purchase-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.inferno-bank-api-gateway.execution_arn}/*/*"
}

# API GATEWAY SAVE ENDPOINT

# API Gateway Resource: /transactions/save
resource "aws_api_gateway_resource" "save" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.transactions.id
  path_part   = "save"
}

# API Gateway Resource: /transactions/save/{card_id}
resource "aws_api_gateway_resource" "save_card_id" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.save.id
  path_part   = "{card_id}"
}

# API Gateway Method: POST /transactions/save/{card_id}
resource "aws_api_gateway_method" "save_post" {
  rest_api_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id   = aws_api_gateway_resource.save_card_id.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.card_id" = true
  }
}

# API Gateway Integration: Lambda for Save
resource "aws_api_gateway_integration" "save_lambda" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id = aws_api_gateway_resource.save_card_id.id
  http_method = aws_api_gateway_method.save_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.card-transaction-save-lambda.invoke_arn

  request_parameters = {
    "integration.request.path.card_id" = "method.request.path.card_id"
  }
}

# Lambda Permission for API Gateway Save
resource "aws_lambda_permission" "api_gateway_lambda_save" {
  statement_id  = "AllowExecutionFromAPIGatewaySave"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.card-transaction-save-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.inferno-bank-api-gateway.execution_arn}/*/*"
}


# API GATEWAY CARD PAID ENDPOINT

# API Gateway Resource: /card
resource "aws_api_gateway_resource" "card" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.root_resource_id
  path_part   = "card"
}

# API Gateway Resource: /card/paid
resource "aws_api_gateway_resource" "card_paid" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.card.id
  path_part   = "paid"
}

# API Gateway Resource: /card/paid/{card_id}
resource "aws_api_gateway_resource" "card_paid_card_id" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.card_paid.id
  path_part   = "{card_id}"
}

# API Gateway Method: POST /card/paid/{card_id}
resource "aws_api_gateway_method" "card_paid_post" {
  rest_api_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id   = aws_api_gateway_resource.card_paid_card_id.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.card_id" = true
  }
}

# API Gateway Integration: Lambda for Card Paid
resource "aws_api_gateway_integration" "card_paid_lambda" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id = aws_api_gateway_resource.card_paid_card_id.id
  http_method = aws_api_gateway_method.card_paid_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.card-paid-credit-card-lambda.invoke_arn

  request_parameters = {
    "integration.request.path.card_id" = "method.request.path.card_id"
  }
}

# Lambda Permission for API Gateway Card Paid
resource "aws_lambda_permission" "api_gateway_lambda_card_paid" {
  statement_id  = "AllowExecutionFromAPIGatewayCardPaid"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.card-paid-credit-card-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.inferno-bank-api-gateway.execution_arn}/*/*"
}

# --- INTEGRACIÓN ENDPOINT /card/activate ---

resource "aws_api_gateway_resource" "card_activate_action" {
  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  parent_id   = aws_api_gateway_resource.card.id
  path_part   = "activate"
}

resource "aws_api_gateway_method" "card_activate_post" {
  rest_api_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id   = aws_api_gateway_resource.card_activate_action.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "card_activate_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  resource_id             = aws_api_gateway_resource.card_activate_action.id
  http_method             = aws_api_gateway_method.card_activate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.card-activate-lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_lambda_card_activate" {
  statement_id  = "AllowExecutionFromAPIGatewayCardActivate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.card-activate-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.inferno-bank-api-gateway.execution_arn}/*/*"
}

# --- FIN INTEGRACIÓN ENDPOINT /card/activate ---

# API Gateway Deployment
resource "aws_api_gateway_deployment" "inferno_bank_api_gateway_deployment" {
  depends_on = [
    aws_api_gateway_method.purchase_post,
    aws_api_gateway_integration.purchase_lambda,
    aws_api_gateway_method.save_post,
    aws_api_gateway_integration.save_lambda,
    aws_api_gateway_method.card_paid_post,
    aws_api_gateway_integration.card_paid_lambda,
    aws_api_gateway_method.card_activate_post,
    aws_api_gateway_integration.card_activate_lambda,
  ]

  rest_api_id = aws_api_gateway_rest_api.inferno-bank-api-gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.purchase_post.id,
      aws_api_gateway_integration.purchase_lambda.id,
      aws_api_gateway_method.save_post.id,
      aws_api_gateway_integration.save_lambda.id,
      aws_api_gateway_method.card_paid_post.id,
      aws_api_gateway_integration.card_paid_lambda.id,
      aws_api_gateway_method.card_activate_post.id,
      aws_api_gateway_integration.card_activate_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.inferno_bank_api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.inferno-bank-api-gateway.id
  stage_name    = var.api_gateway_stage

  tags = {
    Environment = "development"
  }
}


output "api_gateway_transaction_purchase_url" {
  description = "URL completa para invocar el API de purchase"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/transactions/purchase"
}

output "api_gateway_transaction_save_url" {
  description = "URL completa para invocar el API de save"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/transactions/save/{card_id}"
}

output "api_gateway_card_paid_url" {
  description = "URL completa para invocar el API de card paid"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/card/paid/{card_id}"
}

output "api_gateway_card_activate_url" {
  description = "URL completa para invocar el API de card activate"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/card/activate"
}

