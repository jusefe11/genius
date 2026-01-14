# Script para importar secretos existentes al estado de Terraform
# Uso: .\importar-secretos.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Importacion de Secretos a Terraform" -ForegroundColor Cyan
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

# Inicializar Terraform si es necesario
Write-Host "PASO 1: Inicializando Terraform..." -ForegroundColor Yellow
$initOutput = & terraform init 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: terraform init fallo, pero continuando..." -ForegroundColor Yellow
} else {
    Write-Host "OK Terraform inicializado" -ForegroundColor Green
}
Write-Host ""

# Obtener outputs de Terraform para conocer el prefijo
Write-Host "PASO 2: Obteniendo informacion de Terraform..." -ForegroundColor Yellow
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

# Lista de secretos a importar
$secretsToImport = @(
    @{
        Name = "$secretsPrefix/database/credentials"
        Resource = "module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]"
    },
    @{
        Name = "$secretsPrefix/app/api-keys"
        Resource = "module.secrets_manager.aws_secretsmanager_secret.api_keys[0]"
    },
    @{
        Name = "$secretsPrefix/app/jwt_secret"
        Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets['jwt_secret']"
    },
    @{
        Name = "$secretsPrefix/app/encryption_key"
        Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets['encryption_key']"
    }
)

Write-Host "PASO 3: Verificando secretos existentes en AWS..." -ForegroundColor Yellow

$secretsToImportList = @()

foreach ($secretInfo in $secretsToImport) {
    Write-Host "`nVerificando: $($secretInfo.Name)" -ForegroundColor Cyan
    
    # Verificar si el secreto existe
    $describeOutput = & aws secretsmanager describe-secret `
        --secret-id $secretInfo.Name `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secret = ($describeOutput -join "`n") | ConvertFrom-Json
        
        if ($null -eq $secret.DeletedDate) {
            Write-Host "  [OK] Secreto existe y esta ACTIVO" -ForegroundColor Green
            Write-Host "  ARN: $($secret.ARN)" -ForegroundColor Gray
            $secretsToImportList += @{
                Name = $secretInfo.Name
                ARN = $secret.ARN
                Resource = $secretInfo.Resource
            }
        } else {
            Write-Host "  [ADVERTENCIA] Secreto esta ELIMINADO (programado para borrado)" -ForegroundColor Yellow
            Write-Host "  Ejecuta primero: .\restaurar-secretos-automatico.ps1" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [INFO] Secreto no existe en AWS (se creara con terraform apply)" -ForegroundColor Gray
    }
}

if ($secretsToImportList.Count -eq 0) {
    Write-Host "`n[INFO] No hay secretos para importar." -ForegroundColor Yellow
    Write-Host "Todos los secretos se crearan normalmente con terraform apply." -ForegroundColor White
    exit 0
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SECRETOS A IMPORTAR: $($secretsToImportList.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nLos siguientes secretos seran importados al estado de Terraform:" -ForegroundColor White
foreach ($secret in $secretsToImportList) {
    Write-Host "  - $($secret.Name)" -ForegroundColor Gray
    Write-Host "    Recurso: $($secret.Resource)" -ForegroundColor DarkGray
}

# Modo automático: importar sin preguntar
Write-Host "`nImportando automaticamente..." -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IMPORTANDO SECRETOS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

$importedCount = 0
$failedCount = 0

foreach ($secret in $secretsToImportList) {
    Write-Host "`nImportando: $($secret.Name)..." -ForegroundColor Yellow
    Write-Host "  Recurso: $($secret.Resource)" -ForegroundColor Gray
    Write-Host "  ARN: $($secret.ARN)" -ForegroundColor Gray
    
    # Importar el secreto usando -target para evitar dependencias
    $importOutput = & terraform import -target=$secret.Resource $secret.Resource $secret.ARN 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Secreto importado exitosamente" -ForegroundColor Green
        $importedCount++
    } else {
        Write-Host "  [ERROR] No se pudo importar el secreto" -ForegroundColor Red
        Write-Host "  Salida: $($importOutput -join [Environment]::NewLine)" -ForegroundColor Gray
        
        # Verificar si el error es porque ya está importado
        $outputText = $importOutput -join [Environment]::NewLine
        if ($outputText -match "already managed" -or $outputText -match "already in state") {
            Write-Host "  [INFO] El secreto ya esta en el estado de Terraform" -ForegroundColor Yellow
            $importedCount++
        } else {
            $failedCount++
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUMEN DE IMPORTACION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Secretos importados: $importedCount" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "  Secretos con errores: $failedCount" -ForegroundColor Red
}

if ($importedCount -gt 0) {
    Write-Host "`n[OK] Importacion completada." -ForegroundColor Green
    Write-Host "`nAhora puedes ejecutar 'terraform apply' y Terraform actualizara los secretos en lugar de crearlos." -ForegroundColor White
    Write-Host "`nEjecuta:" -ForegroundColor Cyan
    Write-Host "  terraform plan   # Ver que cambios se haran" -ForegroundColor White
    Write-Host "  terraform apply  # Aplicar los cambios" -ForegroundColor White
} else {
    Write-Host "`n[ADVERTENCIA] No se importaron secretos. Revisa los errores arriba." -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Proceso completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
