output "api_gateway_register" {
  description = "URL completa para invocar el API de register"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/register"
}

output "api_gateway_login" {
  description = "URL completa para invocar el API de login"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/login"
}

output "api_gateway_transaction_purchase_url" {
  description = "URL completa para invocar el API de purchase"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/transactions/purchase"
}

output "api_gateway_transaction_save_url" {
  description = "URL completa para invocar el API de save"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/transactions/save/{card_id}"
}

output "api_gateway_card_paid_url" {
  description = "URL completa para invocar el API de card paid"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/card/paid/{card_id}"
}

output "api_gateway_card_activate_url" {
  description = "URL completa para invocar el API de card activate"
  value       = "POST: ${aws_api_gateway_stage.dev.invoke_url}/card/activate"
}

output "api_gateway_card_get_report_url" {
  description = "URL completa para invocar el API de get report"
  value       = "GET: ${aws_api_gateway_stage.dev.invoke_url}/card/{card_id}"
}