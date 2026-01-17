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
  # Comando multiplataforma: detecta el sistema operativo y usa el comando apropiado
  provisioner "local-exec" {
    command = <<-EOT
      if command -v pwsh > /dev/null 2>&1; then
        # PowerShell Core (funciona en Linux/macOS/Windows)
        pwsh -NoProfile -ExecutionPolicy Bypass -Command "$secrets = '${self.triggers.secrets_list}'; $secretsArray = $secrets -split ','; foreach ($secret in $secretsArray) { if ($secret -and ($secret.Trim())) { try { $describe = aws secretsmanager describe-secret --secret-id $secret.Trim() --output json 2>&1; if ($LASTEXITCODE -eq 0) { $obj = $describe | ConvertFrom-Json; if ($obj.DeletedDate) { Write-Host \"Restaurando y eliminando secreto: $secret\"; aws secretsmanager restore-secret --secret-id $secret.Trim() 2>&1 | Out-Null; Start-Sleep -Seconds 2; aws secretsmanager delete-secret --secret-id $secret.Trim() --force-delete-without-recovery 2>&1 | Out-Null; Write-Host \"Secreto limpiado: $secret\"; Start-Sleep -Seconds 1 } } } catch { } } }"
      elif command -v powershell > /dev/null 2>&1; then
        # PowerShell en Windows
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$secrets = '${self.triggers.secrets_list}'; $secretsArray = $secrets -split ','; foreach ($secret in $secretsArray) { if ($secret -and ($secret.Trim())) { try { $describe = aws secretsmanager describe-secret --secret-id $secret.Trim() --output json 2>&1; if ($LASTEXITCODE -eq 0) { $obj = $describe | ConvertFrom-Json; if ($obj.DeletedDate) { Write-Host \"Restaurando y eliminando secreto: $secret\"; aws secretsmanager restore-secret --secret-id $secret.Trim() 2>&1 | Out-Null; Start-Sleep -Seconds 2; aws secretsmanager delete-secret --secret-id $secret.Trim() --force-delete-without-recovery 2>&1 | Out-Null; Write-Host \"Secreto limpiado: $secret\"; Start-Sleep -Seconds 1 } } } catch { } } }"
      elif command -v sh > /dev/null 2>&1; then
        # Bash/Shell en Linux/macOS/Git Bash - compatible con /bin/sh POSIX
        secrets="${self.triggers.secrets_list}"
        OLD_IFS=$$IFS
        IFS=','
        for secret in $$secrets; do
          secret=$$(echo "$$secret" | xargs)
          if [ -n "$$secret" ]; then
            describe_output=$$(aws secretsmanager describe-secret --secret-id "$$secret" --output json 2>/dev/null)
            if [ $$? -eq 0 ]; then
              deleted_date=$$(echo "$$describe_output" | grep -o '"DeletedDate"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
              if [ -n "$$deleted_date" ] && [ "$$deleted_date" != "null" ]; then
                echo "Restaurando y eliminando secreto: $$secret"
                aws secretsmanager restore-secret --secret-id "$$secret" 2>/dev/null || true
                sleep 2
                aws secretsmanager delete-secret --secret-id "$$secret" --force-delete-without-recovery 2>/dev/null || true
                echo "Secreto limpiado: $$secret"
                sleep 1
              fi
            fi
          fi
        done
        IFS=$$OLD_IFS
      else
        echo "Warning: No se encontró PowerShell ni sh. Algunos secretos eliminados pueden no limpiarse automáticamente."
      fi
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
    interpreter = ["sh", "-c"]
    command = <<-EOT
      secrets="${self.triggers.secrets_list}"
      OLD_IFS=$$IFS
      IFS=','
      for secret in $$secrets; do
        secret=$$(echo "$$secret" | xargs)
        if [ -n "$$secret" ]; then
          echo "Limpiando secreto: $$secret"
          aws secretsmanager restore-secret --secret-id "$$secret" 2>/dev/null || true
          sleep 1
          aws secretsmanager delete-secret --secret-id "$$secret" --force-delete-without-recovery 2>/dev/null || true
        fi
      done
      IFS=$$OLD_IFS
    EOT
  }
}
