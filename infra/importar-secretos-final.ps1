# Script final para importar secretos existentes
# Uso: .\importar-secretos-final.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Importacion de Secretos" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
Set-Location $devPath

Write-Host "Importando secretos uno por uno...`n" -ForegroundColor Yellow

# Importar secretos individuales usando el nombre como ID
$imports = @(
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]"; ID = "genius/dev/database/credentials" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.api_keys[0]"; ID = "genius/dev/app/api-keys" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"jwt_secret`"]"; ID = "genius/dev/app/jwt_secret" },
    @{ Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"encryption_key`"]"; ID = "genius/dev/app/encryption_key" }
)

$successCount = 0

foreach ($import in $imports) {
    Write-Host "Importando: $($import.ID)..." -ForegroundColor Cyan
    
    # Usar terraform import directamente
    $output = & terraform import $import.Resource $import.ID 2>&1
    
    $outputText = $output -join [Environment]::NewLine
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Importado exitosamente" -ForegroundColor Green
        $successCount++
    } elseif ($outputText -match "already managed" -or $outputText -match "already in state") {
        Write-Host "  [INFO] Ya esta en el estado" -ForegroundColor Yellow
        $successCount++
    } elseif ($outputText -match "Invalid count argument") {
        Write-Host "  [ADVERTENCIA] Error de dependencias, pero el secreto puede estar importado" -ForegroundColor Yellow
        Write-Host "  Verificando estado..." -ForegroundColor Gray
        
        # Verificar si el secreto está en el estado
        $stateCheck = & terraform state show $import.Resource 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] El secreto esta en el estado (importado previamente)" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  [ERROR] No se pudo importar debido a dependencias" -ForegroundColor Red
            Write-Host "  Solucion: Ejecuta 'terraform apply' y Terraform actualizara los secretos existentes" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] $outputText" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Secretos importados/verificados: $successCount de $($imports.Count)" -ForegroundColor $(if ($successCount -eq $imports.Count) { "Green" } else { "Yellow" })

if ($successCount -eq $imports.Count) {
    Write-Host "`n[OK] Todos los secretos estan en el estado de Terraform" -ForegroundColor Green
    Write-Host "Ahora puedes ejecutar 'terraform apply' y Terraform actualizara los secretos en lugar de crearlos." -ForegroundColor White
} else {
    Write-Host "`n[ADVERTENCIA] Algunos secretos no se pudieron importar debido a dependencias." -ForegroundColor Yellow
    Write-Host "Esto es normal. Ejecuta 'terraform apply' y Terraform:" -ForegroundColor White
    Write-Host "  1. Actualizara los secretos existentes (no los creara de nuevo)" -ForegroundColor Gray
    Write-Host "  2. Creara las versiones de los secretos con los nuevos valores" -ForegroundColor Gray
}

Write-Host "`nEjecuta:" -ForegroundColor Cyan
Write-Host "  terraform plan   # Ver que cambios se haran" -ForegroundColor White
Write-Host "  terraform apply  # Aplicar los cambios" -ForegroundColor White
