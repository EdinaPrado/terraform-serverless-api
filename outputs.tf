output "api_url" {
  description = "URL base da API (já inclui o stage)"
  value       = aws_api_gateway_stage.stage.invoke_url
}

output "api_key_value" {
  description = "Valor da API Key (enviar no header x-api-key)"
  value       = aws_api_gateway_api_key.key.value
  sensitive   = true
}

output "lambda_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.api.arn
}

output "layer_arn" {
  description = "ARN da versão do Lambda Layer"
  value       = aws_lambda_layer_version.common.arn
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = aws_dynamodb_table.products.name
}

output "log_group_name" {
  description = "Log Group da Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
