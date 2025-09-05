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