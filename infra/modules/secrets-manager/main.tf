locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    CostCenter  = var.cost_center
    Owner       = var.owner
    Team        = var.team
    ManagedBy   = var.managed_by
  }

  # Extraer solo las keys de app_secrets (no sensibles) para usar en for_each
  # Las keys no contienen información sensible, solo los valores
  app_secrets_keys = {
    for k in keys(var.app_secrets) : k => k
  }
}

# Secreto principal para credenciales de base de datos
resource "aws_secretsmanager_secret" "db_credentials" {
  count       = var.create_db_secret ? 1 : 0
  name        = "${var.project_name}/${var.environment}/database/credentials"
  description = "Credenciales de base de datos para ${var.project_name} en ambiente ${var.environment}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-credentials"
      Type = "database"
    }
  )
}

# Versión del secreto con las credenciales
resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.create_db_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    database = var.db_name
    engine   = var.db_engine
  })
}

# Secreto para API Keys de la aplicación
resource "aws_secretsmanager_secret" "api_keys" {
  count       = var.create_api_keys_secret ? 1 : 0
  name        = "${var.project_name}/${var.environment}/app/api-keys"
  description = "API Keys para ${var.project_name} en ambiente ${var.environment}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-api-keys"
      Type = "api-keys"
    }
  )
}

# Versión del secreto con las API Keys
resource "aws_secretsmanager_secret_version" "api_keys" {
  count     = var.create_api_keys_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.api_keys[0].id

  secret_string = jsonencode(var.api_keys)
}

# Secreto genérico para otros valores sensibles
# Usamos local.app_secrets_keys (no sensible) para for_each
# Los valores sensibles se acceden mediante var.app_secrets[each.key]
resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = local.app_secrets_keys

  name        = "${var.project_name}/${var.environment}/app/${each.key}"
  description = var.app_secrets[each.key].description != null ? var.app_secrets[each.key].description : "Secreto ${each.key} para ${var.project_name} en ambiente ${var.environment}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}"
      Type = "application"
    }
  )
}

# Versión de los secretos genéricos
# Usamos local.app_secrets_keys (no sensible) para for_each
# El valor sensible se accede mediante var.app_secrets[each.key].secret_string
resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each = local.app_secrets_keys

  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = var.app_secrets[each.key].secret_string
}
