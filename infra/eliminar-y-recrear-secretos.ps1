# Script para eliminar y recrear secretos (si no necesitas el contenido actual)
# Uso: .\eliminar-y-recrear-secretos.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Eliminar y Recrear Secretos" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "[ADVERTENCIA] Esta accion eliminara permanentemente los secretos existentes." -ForegroundColor Red
Write-Host "Perderas todo el contenido actual de los secretos." -ForegroundColor Red
Write-Host "Los secretos se recrearan con los valores de terraform.tfvars.`n" -ForegroundColor Yellow

Write-Host "¿Estas seguro? (escribe 'SI' para confirmar):" -ForegroundColor Red
$confirm = Read-Host

if ($confirm -ne "SI") {
    Write-Host "Operacion cancelada." -ForegroundColor Yellow
    exit 0
}

$region = & aws configure get region 2>&1
if ($LASTEXITCODE -ne 0 -or -not $region) {
    $region = "us-east-1"
} else {
    $region = $region.Trim()
}

$secrets = @(
    "genius/dev/database/credentials",
    "genius/dev/app/api-keys",
    "genius/dev/app/jwt_secret",
    "genius/dev/app/encryption_key"
)

Write-Host "`nEliminando secretos...`n" -ForegroundColor Yellow

foreach ($secretName in $secrets) {
    Write-Host "Eliminando: $secretName" -ForegroundColor Cyan
    
    # Primero restaurar si está eliminado
    $restoreOutput = & aws secretsmanager restore-secret --secret-id $secretName --region $region 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    
    # Eliminar con recovery window de 0 (eliminacion inmediata)
    $deleteOutput = & aws secretsmanager delete-secret `
        --secret-id $secretName `
        --recovery-window-in-days 0 `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Eliminado permanentemente" -ForegroundColor Green
    } else {
        $outputText = $deleteOutput -join [Environment]::NewLine
        if ($outputText -match "ResourceNotFoundException") {
            Write-Host "  [INFO] El secreto no existe (ya fue eliminado)" -ForegroundColor Yellow
        } else {
            Write-Host "  [ERROR] No se pudo eliminar" -ForegroundColor Red
            Write-Host "  $outputText" -ForegroundColor Gray
        }
    }
}

Write-Host "`nEsperando 30 segundos para que AWS procese las eliminaciones..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ELIMINACION COMPLETADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nAhora ejecuta:" -ForegroundColor Cyan
Write-Host "  cd envs\dev" -ForegroundColor White
Write-Host "  terraform apply" -ForegroundColor White
Write-Host "`nTerraform creara los secretos desde cero con los valores de terraform.tfvars." -ForegroundColor White
