# Script para restaurar automáticamente secretos eliminados
# Uso: .\restaurar-secretos-automatico.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Restauracion Automatica de Secretos" -ForegroundColor Cyan
Write-Host "  AWS Secrets Manager" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Obtener región
$region = & aws configure get region 2>&1
if ($LASTEXITCODE -ne 0 -or -not $region) {
    $region = "us-east-1"
    Write-Host "ADVERTENCIA: No se pudo detectar la region, usando: $region" -ForegroundColor Yellow
} else {
    $region = $region.Trim()
}

Write-Host "Region: $region`n" -ForegroundColor Gray

# Lista de secretos que pueden estar eliminados
$secretNames = @(
    "genius/dev/database/credentials",
    "genius/dev/app/api-keys",
    "genius/dev/app/jwt_secret",
    "genius/dev/app/encryption_key"
)

Write-Host "Buscando y restaurando secretos eliminados..." -ForegroundColor Yellow
Write-Host ""

$restoredCount = 0
$notFoundCount = 0
$activeCount = 0

foreach ($secretName in $secretNames) {
    Write-Host "Verificando: $secretName" -ForegroundColor Cyan
    
    # Intentar obtener información del secreto
    $describeOutput = & aws secretsmanager describe-secret `
        --secret-id $secretName `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secret = ($describeOutput -join "`n") | ConvertFrom-Json
        
        if ($null -ne $secret.DeletedDate) {
            # Secreto está eliminado, restaurarlo
            Write-Host "  Estado: ELIMINADO - Restaurando..." -ForegroundColor Yellow
            
            $restoreOutput = & aws secretsmanager restore-secret `
                --secret-id $secretName `
                --region $region `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Secreto restaurado exitosamente" -ForegroundColor Green
                $restoredCount++
            } else {
                Write-Host "  [ERROR] No se pudo restaurar" -ForegroundColor Red
                Write-Host "  Salida: $($restoreOutput -join [Environment]::NewLine)" -ForegroundColor Gray
            }
        } else {
            # Secreto está activo
            Write-Host "  Estado: ACTIVO (no requiere restauración)" -ForegroundColor Green
            $activeCount++
        }
    } else {
        # Secreto no existe
        Write-Host "  Estado: NO EXISTE (se creará con terraform apply)" -ForegroundColor Gray
        $notFoundCount++
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Secretos restaurados: $restoredCount" -ForegroundColor Green
Write-Host "  Secretos activos: $activeCount" -ForegroundColor Green
Write-Host "  Secretos no encontrados: $notFoundCount" -ForegroundColor Gray

if ($restoredCount -gt 0) {
    Write-Host "`n[OK] Secretos restaurados. Ahora puedes ejecutar 'terraform apply'" -ForegroundColor Green
    Write-Host "`nEjecuta:" -ForegroundColor Cyan
    Write-Host "  cd envs\dev" -ForegroundColor White
    Write-Host "  terraform apply" -ForegroundColor White
} elseif ($activeCount -gt 0 -or $notFoundCount -gt 0) {
    Write-Host "`n[OK] No hay secretos eliminados. Puedes ejecutar 'terraform apply' normalmente" -ForegroundColor Green
} else {
    Write-Host "`n[ADVERTENCIA] No se pudo verificar el estado de los secretos" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Proceso completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
