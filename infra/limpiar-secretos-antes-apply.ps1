# Script para limpiar secretos eliminados antes de ejecutar terraform apply
# Uso: .\limpiar-secretos-antes-apply.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Limpieza de Secretos Eliminados" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

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
} else {
    $region = $region.Trim()
}

Write-Host "Region: $region`n" -ForegroundColor Gray

# Obtener outputs de Terraform
Write-Host "PASO 1: Obteniendo informacion de Terraform..." -ForegroundColor Yellow
$tfOutput = & terraform output -json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: No se pudo obtener outputs de Terraform" -ForegroundColor Yellow
    Write-Host "Usando prefijo por defecto: genius/dev" -ForegroundColor Gray
    $secretsPrefix = "genius/dev"
} else {
    $outputs = $tfOutput | ConvertFrom-Json
    $secretsPrefix = $outputs.secrets_prefix.value
}

Write-Host "OK Prefijo de secretos: $secretsPrefix`n" -ForegroundColor Green

# Lista de secretos a verificar
$secretsToCheck = @(
    "$secretsPrefix/database/credentials",
    "$secretsPrefix/app/api-keys",
    "$secretsPrefix/app/jwt_secret",
    "$secretsPrefix/app/encryption_key"
)

Write-Host "PASO 2: Verificando y limpiando secretos eliminados...`n" -ForegroundColor Yellow

$cleanedCount = 0

foreach ($secretName in $secretsToCheck) {
    Write-Host "Verificando: $secretName" -ForegroundColor Cyan
    
    # Verificar si el secreto existe
    $describeOutput = & aws secretsmanager describe-secret `
        --secret-id $secretName `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secret = ($describeOutput -join "`n") | ConvertFrom-Json
        
        if ($null -ne $secret.DeletedDate) {
            Write-Host "  [ENCONTRADO] Secreto esta ELIMINADO (programado para borrado)" -ForegroundColor Yellow
            Write-Host "  Restaurando y eliminando permanentemente..." -ForegroundColor Gray
            
            # Restaurar el secreto
            $restoreOutput = & aws secretsmanager restore-secret `
                --secret-id $secretName `
                --region $region `
                --output json 2>&1 | Out-Null
            
            Start-Sleep -Seconds 2
            
            # Eliminar inmediatamente
            $deleteOutput = & aws secretsmanager delete-secret `
                --secret-id $secretName `
                --force-delete-without-recovery `
                --region $region `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Secreto eliminado permanentemente" -ForegroundColor Green
                $cleanedCount++
            } else {
                Write-Host "  [ERROR] No se pudo eliminar" -ForegroundColor Red
            }
        } else {
            Write-Host "  [OK] Secreto esta ACTIVO (no necesita limpieza)" -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] Secreto no existe (OK para crear)" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "LIMPIEZA COMPLETADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Secretos limpiados: $cleanedCount" -ForegroundColor $(if ($cleanedCount -gt 0) { "Green" } else { "Gray" })

if ($cleanedCount -gt 0) {
    Write-Host "`nEsperando 10 segundos para que AWS procese las eliminaciones..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

Write-Host "`n[OK] Ahora puedes ejecutar 'terraform apply' sin errores." -ForegroundColor Green
Write-Host "`nEjecuta:" -ForegroundColor Cyan
Write-Host "  terraform apply" -ForegroundColor White
