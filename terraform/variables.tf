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
  default     = "card-purchase-table"
}
