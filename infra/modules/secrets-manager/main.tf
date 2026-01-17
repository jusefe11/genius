locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    CostCenter  = var.cost_center
    Owner       = var.owner
    Team        = var.team
    ManagedBy   = var.managed_by
  }
}


# Secreto principal para credenciales de base de datos
resource "aws_secretsmanager_secret" "db_credentials" {
  count       = var.create_db_secret ? 1 : 0
  name        = "${var.project_name}/${var.environment}/database/credentials"
  description = "Credenciales de base de datos para ${var.project_name} en ambiente ${var.environment}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  # Depende del recurso de limpieza para asegurar que se ejecute primero
  depends_on = [null_resource.cleanup_secrets_before_create]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-credentials"
      Type = "database"
    }
  )
  
  # Eliminar inmediatamente sin período de recuperación cuando Terraform destruya el recurso
  # Esto permite que terraform destroy + terraform apply funcione sin errores
  # Primero restaura el secreto si está eliminado, luego lo elimina inmediatamente
  provisioner "local-exec" {
    when    = destroy
    command = "aws secretsmanager restore-secret --secret-id ${self.name} 2>/dev/null || true; aws secretsmanager delete-secret --secret-id ${self.name} --force-delete-without-recovery 2>/dev/null || true"
  }
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

  # Depende del recurso de limpieza para asegurar que se ejecute primero
  depends_on = [null_resource.cleanup_secrets_before_create]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-api-keys"
      Type = "api-keys"
    }
  )
  
  # Eliminar inmediatamente sin período de recuperación cuando Terraform destruya el recurso
  # Esto permite que terraform destroy + terraform apply funcione sin errores
  # Primero restaura el secreto si está eliminado, luego lo elimina inmediatamente
  provisioner "local-exec" {
    when    = destroy
    command = "aws secretsmanager restore-secret --secret-id ${self.name} 2>/dev/null || true; aws secretsmanager delete-secret --secret-id ${self.name} --force-delete-without-recovery 2>/dev/null || true"
  }
}

# Versión del secreto con las API Keys
resource "aws_secretsmanager_secret_version" "api_keys" {
  count     = var.create_api_keys_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.api_keys[0].id

  secret_string = jsonencode(var.api_keys)
}

# Secreto genérico para otros valores sensibles
# Usamos nonsensitive(keys()) porque las keys no contienen información sensible
# Solo los valores (secret_string) son sensibles, no los nombres de las keys
# Los valores sensibles se acceden mediante var.app_secrets[each.key]
resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = toset(nonsensitive(keys(var.app_secrets)))

  name        = "${var.project_name}/${var.environment}/app/${each.key}"
  description = var.app_secrets[each.key].description != null ? var.app_secrets[each.key].description : "Secreto ${each.key} para ${var.project_name} en ambiente ${var.environment}"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  # Depende del recurso de limpieza para asegurar que se ejecute primero
  depends_on = [null_resource.cleanup_secrets_before_create]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}"
      Type = "application"
    }
  )
  
  # Eliminar inmediatamente sin período de recuperación cuando Terraform destruya el recurso
  # Esto permite que terraform destroy + terraform apply funcione sin errores
  # Primero restaura el secreto si está eliminado, luego lo elimina inmediatamente
  provisioner "local-exec" {
    when    = destroy
    command = "aws secretsmanager restore-secret --secret-id ${self.name} 2>/dev/null || true; aws secretsmanager delete-secret --secret-id ${self.name} --force-delete-without-recovery 2>/dev/null || true"
  }
}

# Versión de los secretos genéricos
# Usamos nonsensitive(keys()) porque las keys no contienen información sensible
# El valor sensible se accede mediante var.app_secrets[each.key].secret_string
resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each = toset(nonsensitive(keys(var.app_secrets)))

  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = var.app_secrets[each.key].secret_string
}

# Recurso null que limpia los secretos ANTES de crearlos (durante apply)
# Esto garantiza que si los secretos están en período de recuperación, se eliminen primero
resource "null_resource" "cleanup_secrets_before_create" {
  # Lista de todos los nombres de secretos posibles
  triggers = {
    # Trigger que cambia cuando cambian los secretos a crear
    secrets_list = join(",", concat(
      var.create_db_secret ? ["${var.project_name}/${var.environment}/database/credentials"] : [],
      var.create_api_keys_secret ? ["${var.project_name}/${var.environment}/app/api-keys"] : [],
      [for k in keys(var.app_secrets) : "${var.project_name}/${var.environment}/app/${k}"]
    ))
    # Trigger adicional para forzar ejecución en cada apply
    force_cleanup = timestamp()
  }

  # Durante create (antes de crear los secretos), limpia cualquier secreto eliminado
  # Esto se ejecuta SIEMPRE antes de que Terraform intente crear los secretos
  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      secrets="${self.triggers.secrets_list}"
      echo "$$secrets" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//' | while read secret; do
        if [ -n "$$secret" ]; then
          if aws secretsmanager describe-secret --secret-id "$$secret" --output json 2>/dev/null | grep -q '"DeletedDate"'; then
            echo "Restaurando y eliminando secreto: $$secret"
            aws secretsmanager restore-secret --secret-id "$$secret" 2>/dev/null || true
            sleep 2
            aws secretsmanager delete-secret --secret-id "$$secret" --force-delete-without-recovery 2>/dev/null || true
            echo "Secreto limpiado: $$secret"
            sleep 1
          fi
        fi
      done
    EOT
  }
}

# Recurso null que siempre limpia los secretos durante destroy
# Esto garantiza que los secretos se eliminen completamente, incluso si no están en el estado
resource "null_resource" "cleanup_secrets_on_destroy" {
  # Depende de todos los secretos para ejecutarse después de ellos
  depends_on = [
    aws_secretsmanager_secret.db_credentials,
    aws_secretsmanager_secret.api_keys,
    aws_secretsmanager_secret.app_secrets
  ]

  # Lista de todos los nombres de secretos posibles
  triggers = {
    # Trigger que cambia cuando se crean/destruyen secretos
    secrets_list = join(",", concat(
      var.create_db_secret ? ["${var.project_name}/${var.environment}/database/credentials"] : [],
      var.create_api_keys_secret ? ["${var.project_name}/${var.environment}/app/api-keys"] : [],
      [for k in keys(var.app_secrets) : "${var.project_name}/${var.environment}/app/${k}"]
    ))
  }

  # Durante destroy, limpia TODOS los secretos posibles
  # Esto se ejecuta SIEMPRE, incluso si los secretos no están en el estado
  # Usamos self.triggers.secrets_list que contiene la lista de secretos guardada durante la creación
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      secrets="${self.triggers.secrets_list}"
      echo "$$secrets" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//' | while read secret; do
        if [ -n "$$secret" ]; then
          echo "Limpiando secreto: $$secret"
          aws secretsmanager restore-secret --secret-id "$$secret" 2>/dev/null || true
          sleep 1
          aws secretsmanager delete-secret --secret-id "$$secret" --force-delete-without-recovery 2>/dev/null || true
        fi
      done
    EOT
  }
}
