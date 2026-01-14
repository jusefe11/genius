# Script para gestionar secretos eliminados en AWS Secrets Manager
# Uso: .\gestionar-secretos-eliminados.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Gestion de Secretos Eliminados" -ForegroundColor Cyan
Write-Host "  AWS Secrets Manager" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la carpeta infra/" -ForegroundColor Yellow
    exit 1
}

Set-Location $devPath

# Obtener región
$region = & aws configure get region 2>&1
if ($LASTEXITCODE -ne 0 -or -not $region) {
    $region = "us-east-1"
    Write-Host "ADVERTENCIA: No se pudo detectar la region, usando: $region" -ForegroundColor Yellow
} else {
    $region = $region.Trim()
}

Write-Host "Region: $region`n" -ForegroundColor Gray

# Obtener outputs de Terraform
Write-Host "PASO 1: Obteniendo informacion de Terraform..." -ForegroundColor Yellow
$tfOutput = & terraform output -json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo obtener outputs de Terraform" -ForegroundColor Red
    Write-Host "Asegurate de haber ejecutado 'terraform apply' primero" -ForegroundColor Yellow
    exit 1
}

$outputs = $tfOutput | ConvertFrom-Json
$secretsPrefix = $outputs.secrets_prefix.value

Write-Host "OK Prefijo de secretos: $secretsPrefix" -ForegroundColor Green

# Listar secretos con el prefijo
Write-Host "`nPASO 2: Buscando secretos eliminados..." -ForegroundColor Yellow
$listOutput = & aws secretsmanager list-secrets `
    --filters Key=name,Values=$secretsPrefix `
    --region $region `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo listar secretos" -ForegroundColor Red
    Write-Host "Salida: $($listOutput -join [Environment]::NewLine)" -ForegroundColor Gray
    exit 1
}

$secretsList = ($listOutput -join "`n") | ConvertFrom-Json
$deletedSecrets = @()

if ($secretsList.SecretList.Count -gt 0) {
    Write-Host "`nSe encontraron $($secretsList.SecretList.Count) secretos:" -ForegroundColor Cyan
    
    foreach ($secret in $secretsList.SecretList) {
        $isDeleted = $null -ne $secret.DeletedDate
        $status = if ($isDeleted) { "ELIMINADO (programado para borrado)" } else { "ACTIVO" }
        $color = if ($isDeleted) { "Red" } else { "Green" }
        
        Write-Host "`n  - $($secret.Name)" -ForegroundColor White
        Write-Host "    Estado: $status" -ForegroundColor $color
        Write-Host "    ARN: $($secret.ARN)" -ForegroundColor Gray
        
        if ($isDeleted) {
            $deletedDate = [DateTime]::Parse($secret.DeletedDate)
            $recoveryWindow = if ($secret.Description -match "prod") { 30 } else { 7 }
            $recoveryEndDate = $deletedDate.AddDays($recoveryWindow)
            $daysRemaining = ($recoveryEndDate - (Get-Date)).Days
            
            Write-Host "    Eliminado: $($deletedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "    Periodo de recuperacion: $recoveryWindow dias" -ForegroundColor Gray
            Write-Host "    Recuperable hasta: $($recoveryEndDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "    Dias restantes: $daysRemaining" -ForegroundColor $(if ($daysRemaining -gt 0) { "Yellow" } else { "Red" })
            
            $deletedSecrets += @{
                Name = $secret.Name
                ARN = $secret.ARN
                DeletedDate = $deletedDate
                RecoveryEndDate = $recoveryEndDate
                DaysRemaining = $daysRemaining
            }
        }
    }
} else {
    Write-Host "`nNo se encontraron secretos con el prefijo '$secretsPrefix'" -ForegroundColor Yellow
    exit 0
}

if ($deletedSecrets.Count -eq 0) {
    Write-Host "`n[OK] No hay secretos eliminados. Puedes crear los secretos normalmente." -ForegroundColor Green
    exit 0
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SECRETOS ELIMINADOS ENCONTRADOS: $($deletedSecrets.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nOPCIONES:" -ForegroundColor Cyan
Write-Host "  1. Restaurar secretos eliminados (RECOMENDADO)" -ForegroundColor Green
Write-Host "     - Restaura los secretos para poder usarlos de nuevo" -ForegroundColor Gray
Write-Host "     - Terraform podra crear/actualizar los secretos normalmente" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Forzar eliminacion inmediata" -ForegroundColor Red
Write-Host "     - Elimina permanentemente los secretos (NO RECOMENDADO)" -ForegroundColor Gray
Write-Host "     - Perderas el contenido de los secretos" -ForegroundColor Gray
Write-Host "     - Despues podras crear nuevos secretos con los mismos nombres" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Esperar a que termine el periodo de recuperacion" -ForegroundColor Yellow
Write-Host "     - Los secretos se eliminaran automaticamente" -ForegroundColor Gray
Write-Host "     - Tiempo de espera: $($deletedSecrets[0].DaysRemaining) dias" -ForegroundColor Gray
Write-Host ""
Write-Host "Selecciona una opcion (1-3):" -ForegroundColor Cyan
$option = Read-Host

switch ($option) {
    "1" {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "RESTAURANDO SECRETOS ELIMINADOS" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        foreach ($secret in $deletedSecrets) {
            Write-Host "`nRestaurando: $($secret.Name)..." -ForegroundColor Yellow
            
            $restoreOutput = & aws secretsmanager restore-secret `
                --secret-id $secret.Name `
                --region $region `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Secreto restaurado exitosamente" -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] No se pudo restaurar el secreto" -ForegroundColor Red
                Write-Host "  Salida: $($restoreOutput -join [Environment]::NewLine)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "RESTAURACION COMPLETADA" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nAhora puedes ejecutar 'terraform apply' de nuevo." -ForegroundColor Green
    }
    
    "2" {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "FORZANDO ELIMINACION INMEDIATA" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`n[ADVERTENCIA] Esta accion eliminara permanentemente los secretos." -ForegroundColor Yellow
        Write-Host "Perderas todo el contenido de los secretos." -ForegroundColor Yellow
        Write-Host "`n¿Estas seguro? (escribe 'SI' para confirmar):" -ForegroundColor Red
        $confirm = Read-Host
        
        if ($confirm -ne "SI") {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            exit 0
        }
        
        foreach ($secret in $deletedSecrets) {
            Write-Host "`nEliminando permanentemente: $($secret.Name)..." -ForegroundColor Yellow
            
            # Primero restaurar para poder eliminarlo inmediatamente
            $restoreOutput = & aws secretsmanager restore-secret `
                --secret-id $secret.Name `
                --region $region `
                --output json 2>&1 | Out-Null
            
            Start-Sleep -Seconds 2
            
            # Ahora eliminar con recovery window de 0 (eliminacion inmediata)
            $deleteOutput = & aws secretsmanager delete-secret `
                --secret-id $secret.Name `
                --recovery-window-in-days 0 `
                --region $region `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Secreto eliminado permanentemente" -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] No se pudo eliminar el secreto" -ForegroundColor Red
                Write-Host "  Salida: $($deleteOutput -join [Environment]::NewLine)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "ELIMINACION COMPLETADA" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nEspera 30-60 segundos y luego ejecuta 'terraform apply' de nuevo." -ForegroundColor Green
    }
    
    "3" {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "ESPERANDO PERIODO DE RECUPERACION" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nLos secretos se eliminaran automaticamente en:" -ForegroundColor Yellow
        foreach ($secret in $deletedSecrets) {
            Write-Host "  - $($secret.Name): $($secret.DaysRemaining) dias restantes" -ForegroundColor Gray
            Write-Host "    (Fecha: $($secret.RecoveryEndDate.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor Gray
        }
        Write-Host "`nDespues de esa fecha, podras crear nuevos secretos con los mismos nombres." -ForegroundColor White
    }
    
    default {
        Write-Host "Opcion invalida." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Proceso completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
