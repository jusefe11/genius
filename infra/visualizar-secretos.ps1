# Script para visualizar secretos de AWS Secrets Manager
# Uso: .\visualizar-secretos.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Visualizacion de Secretos AWS" -ForegroundColor Cyan
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
    Write-Host "`n[ERROR] NO HAY SECRETOS CONFIGURADOS" -ForegroundColor Red
    Write-Host "`nLos secretos no se han creado aun." -ForegroundColor Yellow
    Write-Host "`nPara crear secretos:" -ForegroundColor Cyan
    Write-Host "  1. Configura los secretos en envs\dev\terraform.tfvars" -ForegroundColor White
    Write-Host "  2. Ejecuta: terraform plan" -ForegroundColor White
    Write-Host "  3. Ejecuta: terraform apply" -ForegroundColor White
    exit 1
}

Write-Host "OK Se encontraron $($allSecretArns.Count) secretos configurados`n" -ForegroundColor Green

# Mostrar cada secreto
$secretNumber = 1
foreach ($secretArn in $allSecretArns) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SECRETO $secretNumber de $($allSecretArns.Count)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Extraer nombre del secreto desde el ARN
    $fullSecretName = $secretArn -replace ".*:secret:", ""
    
    Write-Host "`nARN: $secretArn" -ForegroundColor Gray
    Write-Host "Nombre: $fullSecretName" -ForegroundColor White
    
    # Obtener información del secreto
    Write-Host "`nObteniendo informacion del secreto..." -ForegroundColor Yellow
    $describeOutput = & aws secretsmanager describe-secret `
        --secret-id $fullSecretName `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secretInfo = ($describeOutput -join "`n") | ConvertFrom-Json
        Write-Host "  Descripcion: $($secretInfo.Description)" -ForegroundColor Gray
        Write-Host "  Estado: $(if ($secretInfo.DeletedDate) { 'ELIMINADO' } else { 'ACTIVO' })" -ForegroundColor $(if ($secretInfo.DeletedDate) { "Red" } else { "Green" })
        Write-Host "  Creado: $($secretInfo.CreatedDate)" -ForegroundColor Gray
    } else {
        Write-Host "  [ADVERTENCIA] No se pudo obtener informacion del secreto" -ForegroundColor Yellow
    }
    
    # Obtener el valor del secreto
    Write-Host "`nObteniendo valor del secreto..." -ForegroundColor Yellow
    $getValueOutput = & aws secretsmanager get-secret-value `
        --secret-id $fullSecretName `
        --region $region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secretValue = ($getValueOutput -join "`n") | ConvertFrom-Json
        
        # Intentar parsear como JSON
        try {
            $secretJson = $secretValue.SecretString | ConvertFrom-Json
            Write-Host "`n[CONTENIDO DEL SECRETO (JSON)]:" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Gray
            
            # Mostrar cada campo del JSON
            $secretJson.PSObject.Properties | ForEach-Object {
                $key = $_.Name
                $value = $_.Value
                # Ocultar valores sensibles parcialmente
                if ($key -match "password|secret|key|token|api") {
                    $displayValue = if ($value.Length -gt 8) {
                        $value.Substring(0, 4) + "..." + $value.Substring($value.Length - 4)
                    } else {
                        "***"
                    }
                    Write-Host "  $key : $displayValue" -ForegroundColor Yellow
                } else {
                    Write-Host "  $key : $value" -ForegroundColor White
                }
            }
        } catch {
            # Si no es JSON, mostrarlo como texto
            Write-Host "`n[CONTENIDO DEL SECRETO (TEXTO)]:" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Gray
            $displayValue = if ($secretValue.SecretString.Length -gt 50) {
                $secretValue.SecretString.Substring(0, 25) + "..." + $secretValue.SecretString.Substring($secretValue.SecretString.Length - 10)
            } else {
                $secretValue.SecretString
            }
            Write-Host "  $displayValue" -ForegroundColor White
        }
        
        Write-Host "`n[URL EN LA CONSOLA DE AWS]:" -ForegroundColor Cyan
        $consoleUrl = "https://console.aws.amazon.com/secretsmanager/home?region=$region#/secret?name=$($fullSecretName -replace '/', '%2F')"
        Write-Host "  $consoleUrl" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] No se pudo obtener el valor del secreto" -ForegroundColor Red
        Write-Host "  Salida: $($getValueOutput -join [Environment]::NewLine)" -ForegroundColor Gray
        Write-Host "`n  Posibles causas:" -ForegroundColor Yellow
        Write-Host "    - No tienes permisos para leer el secreto" -ForegroundColor Gray
        Write-Host "    - El secreto fue eliminado" -ForegroundColor Gray
        Write-Host "    - El secreto no existe" -ForegroundColor Gray
    }
    
    Write-Host ""
    $secretNumber++
}

# Resumen
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nTotal de secretos: $($allSecretArns.Count)" -ForegroundColor Green
Write-Host "Prefijo: $secretsPrefix" -ForegroundColor Gray
Write-Host "Region: $region" -ForegroundColor Gray

Write-Host "`n[ACCESO RAPIDO A LA CONSOLA]:" -ForegroundColor Cyan
$listUrl = "https://console.aws.amazon.com/secretsmanager/home?region=$region#/listSecrets"
Write-Host "  Lista de secretos: $listUrl" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Visualizacion completada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
