# Script simple para importar secretos existentes
# Uso: .\importar-secretos-simple.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Importacion Simple de Secretos" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
Set-Location $devPath

Write-Host "Importando secretos al estado de Terraform...`n" -ForegroundColor Yellow

# Lista de secretos a importar (usando el nombre como ID, no el ARN completo)
$imports = @(
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]"; ID = "genius/dev/database/credentials" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.api_keys[0]"; ID = "genius/dev/app/api-keys" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"jwt_secret`"]"; ID = "genius/dev/app/jwt_secret" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"encryption_key`"]"; ID = "genius/dev/app/encryption_key" }
)

$successCount = 0
$errorCount = 0

foreach ($import in $imports) {
    Write-Host "Importando: $($import.ID)..." -ForegroundColor Cyan
    Write-Host "  Recurso: $($import.Resource)" -ForegroundColor Gray
    
    # Usar -target para evitar evaluar dependencias
    $output = & terraform import -target=$import.Resource $import.Resource $import.ID 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Importado exitosamente" -ForegroundColor Green
        $successCount++
    } else {
        $outputText = $output -join [Environment]::NewLine
        if ($outputText -match "already managed" -or $outputText -match "already in state") {
            Write-Host "  [INFO] Ya esta en el estado" -ForegroundColor Yellow
            $successCount++
        } else {
            Write-Host "  [ERROR] Fallo la importacion" -ForegroundColor Red
            Write-Host "  $outputText" -ForegroundColor Gray
            $errorCount++
        }
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Importados/Existentes: $successCount" -ForegroundColor Green
Write-Host "  Errores: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })

if ($successCount -gt 0) {
    Write-Host "`n[OK] Ahora puedes ejecutar 'terraform apply'" -ForegroundColor Green
}
