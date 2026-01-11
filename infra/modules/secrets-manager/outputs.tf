# Outputs para el secreto de base de datos
output "db_secret_arn" {
  description = "ARN del secreto de credenciales de base de datos"
  value       = var.create_db_secret ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

output "db_secret_name" {
  description = "Nombre del secreto de credenciales de base de datos"
  value       = var.create_db_secret ? aws_secretsmanager_secret.db_credentials[0].name : null
}

# Outputs para el secreto de API Keys
output "api_keys_secret_arn" {
  description = "ARN del secreto de API Keys"
  value       = var.create_api_keys_secret ? aws_secretsmanager_secret.api_keys[0].arn : null
}

output "api_keys_secret_name" {
  description = "Nombre del secreto de API Keys"
  value       = var.create_api_keys_secret ? aws_secretsmanager_secret.api_keys[0].name : null
}

# Outputs para secretos genéricos
output "app_secrets_arns" {
  description = "Mapa de ARNs de secretos genéricos (clave: nombre del secreto, valor: ARN)"
  value = {
    for k, v in aws_secretsmanager_secret.app_secrets : k => v.arn
  }
}

output "app_secrets_names" {
  description = "Mapa de nombres de secretos genéricos (clave: nombre del secreto, valor: nombre completo)"
  value = {
    for k, v in aws_secretsmanager_secret.app_secrets : k => v.name
  }
}

# Output combinado con todos los secretos
output "all_secret_arns" {
  description = "Lista de todos los ARNs de secretos creados"
  value = concat(
    var.create_db_secret ? [aws_secretsmanager_secret.db_credentials[0].arn] : [],
    var.create_api_keys_secret ? [aws_secretsmanager_secret.api_keys[0].arn] : [],
    [for secret in aws_secretsmanager_secret.app_secrets : secret.arn]
  )
}

output "secrets_prefix" {
  description = "Prefijo común para todos los secretos de este proyecto/ambiente"
  value       = "${var.project_name}/${var.environment}"
}
