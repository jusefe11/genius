# Script para eliminar definitivamente los secretos
# Uso: .\eliminar-secretos-definitivo.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Eliminacion Definitiva de Secretos" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

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

Write-Host "Eliminando secretos permanentemente...`n" -ForegroundColor Yellow

foreach ($secretName in $secrets) {
    Write-Host "Procesando: $secretName" -ForegroundColor Cyan
    
    # Paso 1: Verificar estado
    $describe = & aws secretsmanager describe-secret --secret-id $secretName --region $region --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secretObj = ($describe -join "`n") | ConvertFrom-Json
        
        # Paso 2: Si está eliminado, restaurarlo primero
        if ($null -ne $secretObj.DeletedDate) {
            Write-Host "  Restaurando secreto eliminado..." -ForegroundColor Yellow
            & aws secretsmanager restore-secret --secret-id $secretName --region $region 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }
        
        # Paso 3: Eliminar con recovery window de 0
        Write-Host "  Eliminando permanentemente..." -ForegroundColor Yellow
        $delete = & aws secretsmanager delete-secret --secret-id $secretName --recovery-window-in-days 0 --region $region --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Eliminado permanentemente" -ForegroundColor Green
        } else {
            $deleteText = $delete -join [Environment]::NewLine
            Write-Host "  [ERROR] $deleteText" -ForegroundColor Red
        }
    } else {
        Write-Host "  [INFO] No existe" -ForegroundColor Gray
    }
}

Write-Host "`nEsperando 60 segundos para que AWS procese las eliminaciones..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ELIMINACION COMPLETADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nAhora ejecuta:" -ForegroundColor Cyan
Write-Host "  cd envs\dev" -ForegroundColor White
Write-Host "  terraform apply" -ForegroundColor White
