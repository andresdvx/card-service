variable "sqs_create_request_card" {
  description = "SQS para la creación de tarjetas DEBITO / CRÉDITO"
  type        = string
  default     = "create-request-card-sqs"
}

variable "lambda_sqs_create_card" {
  description = "Handler de la lambda para el procesamiento de la cola SQS de creación de tarjetas DEBITO / CRÉDITO"
  type        = string
  default     = "create-request-card-lambda"
}

variable "lambda_sqs_create_card_handler" {
  description = "Handler de la lambda para el procesamiento de la cola SQS de creación de tarjetas DEBITO / CRÉDITO"
  type        = string
  default     = "create-request-card-lambda.handler"
}

variable "dynamodb_table_card" {
  description = "Nombre de la tabla DynamoDB para almacenar la información de las tarjetas"
  type        = string
  default     = "card-table"
}

variable "lambda_dlq_request_card_failed" {
  description = "Handler de la lambda para el procesamiento de la cola DLQ de creación de tarjetas fallidas"
  type        = string
  default     = "card-request-failed"
}

variable "lambda_dlq_request_card_failed_handler" {
  description = "Handler de la lambda para el procesamiento de la cola DLQ de creación de tarjetas fallidas"
  type        = string
  default     = "card-request-failed-lambda.handler"
}

variable "dynamodb_table_errors" {
  description = "Nombre de la tabla DynamoDB para almacenar la información de los errores"
  type        = string
  default     = "card-table-error"
}

variable "lambda_card_purchase" {
  description = "value"
  type        = string
  default     = "card-purchase-lambda"
}

variable "lambda_card_purchase_handler" {
  description = "value"
  type        = string
  default     = "card-purchase-lambda.handler"
}

variable "dynamodb_table_card_purchase" {
  description = "value"
  type        = string
  default     = "transaction-table"
}

variable "lambda_card_transaction_save" {
  description = "value"
  type        = string
  default     = "card-transaction-save-lambda"
}

variable "lambda_card_transaction_save_handler" {
  description = "value"
  type        = string
  default     = "card-transaction-save-lambda.handler"
}

variable "lambda_card_paid_credit_card" {
  description = "Lambda para procesar pagos de cupo usado de la tarjeta"
  type        = string
  default     = "card-paid-credit-card-lambda"
}

variable "lambda_card_paid_credit_card_handler" {
  description = "Handler de la Lambda para procesar pagos de cupo usado de la tarjeta"
  type        = string
  default     = "card-paid-credit-card-lambda.handler"
}

variable "lambda_card_activate" {
  description = "Lambda para activar la tarjeta"
  type        = string
  default     = "card-activate-lambda"
}

variable "lambda_card_activate_handler" {
  description = "Handler de la Lambda para activar la tarjeta"
  type        = string
  default     = "card-activate-lambda.handler"
}

variable "api_gateway_name" {
  description = "Nombre del API Gateway"
  type        = string
  default     = "inferno-bank-api-gateway"
}

variable "api_gateway_stage" {
  description = "Stage del API Gateway"
  type        = string
  default     = "dev"
}