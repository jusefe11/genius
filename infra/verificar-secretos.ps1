# Script para verificar el estado de los secretos en AWS Secrets Manager
# Uso: .\verificar-secretos.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verificacion de Secretos AWS" -ForegroundColor Cyan
Write-Host "  Secrets Manager" -ForegroundColor Cyan
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
$allSecretArns = $outputs.all_secret_arns.value

Write-Host "OK Prefijo de secretos: $secretsPrefix" -ForegroundColor Green

if ($allSecretArns.Count -eq 0) {
    Write-Host "`n[ADVERTENCIA] NO HAY SECRETOS CONFIGURADOS" -ForegroundColor Yellow
    Write-Host "`nRazon: Los secretos estan deshabilitados en terraform.tfvars" -ForegroundColor Gray
    Write-Host "`nPara habilitar secretos:" -ForegroundColor Cyan
    Write-Host "  1. Edita el archivo: envs\dev\terraform.tfvars" -ForegroundColor White
    Write-Host "  2. Descomenta y configura las variables de secretos" -ForegroundColor White
    Write-Host "  3. Ejecuta: terraform plan" -ForegroundColor White
    Write-Host "  4. Ejecuta: terraform apply" -ForegroundColor White
    Write-Host "`nEjemplo de configuracion:" -ForegroundColor Cyan
    Write-Host "  create_db_secret = true" -ForegroundColor Gray
    Write-Host "  db_username      = `"myapp_user`"" -ForegroundColor Gray
    Write-Host "  db_password      = `"SuperSecurePassword123!`"" -ForegroundColor Gray
    Write-Host "  db_host          = `"mydb.example.com`"" -ForegroundColor Gray
    Write-Host "  db_port          = 3306" -ForegroundColor Gray
    Write-Host "  db_name          = `"myapp_db`"" -ForegroundColor Gray
    Write-Host "  db_engine        = `"mysql`"" -ForegroundColor Gray
    exit 0
}

Write-Host "OK Se encontraron $($allSecretArns.Count) secretos configurados" -ForegroundColor Green

# Verificar cada secreto en AWS
Write-Host "`nPASO 2: Verificando secretos en AWS Secrets Manager..." -ForegroundColor Yellow
foreach ($secretArn in $allSecretArns) {
    Write-Host "`nVerificando: $secretArn" -ForegroundColor Cyan
    
    # Obtener nombre del secreto desde el ARN
    $secretName = $secretArn -replace ".*:secret:", "" -replace "/.*", ""
    $fullSecretName = $secretArn -replace ".*:secret:", ""
    
    # Consultar el secreto
    $secretOutput = & aws secretsmanager describe-secret `
        --secret-id $fullSecretName `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secret = ($secretOutput -join "`n") | ConvertFrom-Json
        Write-Host "  [OK] Secreto existe" -ForegroundColor Green
        Write-Host "  Nombre: $($secret.Name)" -ForegroundColor Gray
        Write-Host "  Descripcion: $($secret.Description)" -ForegroundColor Gray
        $estado = if ($secret.DeletedDate) { "ELIMINADO" } else { "ACTIVO" }
        $colorEstado = if ($secret.DeletedDate) { "Red" } else { "Green" }
        Write-Host "  Estado: $estado" -ForegroundColor $colorEstado
        Write-Host "  ARN: $($secret.ARN)" -ForegroundColor Gray
        
        # Verificar si tiene versiones
        if ($secret.VersionIdsToStages) {
            $versionCount = ($secret.VersionIdsToStages.PSObject.Properties | Measure-Object).Count
            Write-Host "  Versiones: $versionCount" -ForegroundColor Gray
        } else {
            Write-Host "  [ADVERTENCIA] El secreto no tiene versiones (esta vacio)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] No se pudo consultar el secreto" -ForegroundColor Red
        Write-Host "  Salida: $($secretOutput -join [Environment]::NewLine)" -ForegroundColor Gray
    }
}

# Listar todos los secretos con el prefijo
Write-Host "`nPASO 3: Listando todos los secretos con prefijo '$secretsPrefix'..." -ForegroundColor Yellow
$listOutput = & aws secretsmanager list-secrets `
    --filters Key=name,Values=$secretsPrefix `
    --region $region `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {
    $secretsList = ($listOutput -join "`n") | ConvertFrom-Json
    if ($secretsList.SecretList.Count -gt 0) {
        Write-Host "`nSe encontraron $($secretsList.SecretList.Count) secretos en AWS:" -ForegroundColor Green
        foreach ($secret in $secretsList.SecretList) {
            Write-Host "  - $($secret.Name)" -ForegroundColor White
            Write-Host "    ARN: $($secret.ARN)" -ForegroundColor Gray
            Write-Host "    Descripcion: $($secret.Description)" -ForegroundColor Gray
        }
    } else {
        Write-Host "`nNo se encontraron secretos con el prefijo '$secretsPrefix' en AWS" -ForegroundColor Yellow
        Write-Host "Esto confirma que los secretos NO se han creado" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[ADVERTENCIA] No se pudo listar secretos" -ForegroundColor Yellow
    Write-Host "Salida: $($listOutput -join [Environment]::NewLine)" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verificacion completada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
