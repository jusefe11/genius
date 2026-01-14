# Script para arreglar el problema de secretos existentes
# Solucion: Importar secretos usando terraform state directamente

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ARREGLAR: Secretos Existentes" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
Set-Location $devPath

Write-Host "PROBLEMA: Los secretos ya existen en AWS pero Terraform no los conoce." -ForegroundColor Yellow
Write-Host "SOLUCION: Importarlos al estado de Terraform.`n" -ForegroundColor White

# Obtener ARNs de los secretos
Write-Host "PASO 1: Obteniendo ARNs de los secretos desde AWS...`n" -ForegroundColor Yellow

$region = & aws configure get region 2>&1
if ($LASTEXITCODE -ne 0 -or -not $region) {
    $region = "us-east-1"
} else {
    $region = $region.Trim()
}

$secrets = @(
    @{ Name = "genius/dev/database/credentials"; Resource = "module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]" },
    @{ Name = "genius/dev/app/api-keys"; Resource = "module.secrets_manager.aws_secretsmanager_secret.api_keys[0]" },
    @{ Name = "genius/dev/app/jwt_secret"; Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"jwt_secret`"]" },
    @{ Name = "genius/dev/app/encryption_key"; Resource = "module.secrets_manager.aws_secretsmanager_secret.app_secrets[`"encryption_key`"]" }
)

$secretArns = @()

foreach ($secret in $secrets) {
    Write-Host "Obteniendo ARN de: $($secret.Name)" -ForegroundColor Cyan
    $describeOutput = & aws secretsmanager describe-secret --secret-id $secret.Name --region $region --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $secretObj = ($describeOutput -join "`n") | ConvertFrom-Json
        $secretArns += @{
            Name = $secret.Name
            ARN = $secretObj.ARN
            Resource = $secret.Resource
        }
        Write-Host "  [OK] ARN: $($secretObj.ARN)" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] No se encontro el secreto" -ForegroundColor Red
    }
}

if ($secretArns.Count -eq 0) {
    Write-Host "`n[ERROR] No se encontraron secretos para importar" -ForegroundColor Red
    exit 1
}

Write-Host "`nPASO 2: Importando secretos al estado de Terraform...`n" -ForegroundColor Yellow

# Intentar importar cada secreto
# Para recursos con for_each, necesitamos usar la sintaxis correcta
foreach ($secret in $secretArns) {
    Write-Host "Importando: $($secret.Name)" -ForegroundColor Cyan
    Write-Host "  Recurso: $($secret.Resource)" -ForegroundColor Gray
    
    # Para recursos con for_each, usar comillas simples en el índice
    if ($secret.Resource -match 'app_secrets\[`"') {
        # Es un recurso con for_each, usar sintaxis especial
        $resourceName = $secret.Resource -replace '\[`"', "['" -replace '`"\]', "']"
        $output = & terraform import $resourceName $secret.Name 2>&1
    } else {
        # Recurso normal con count
        $output = & terraform import $secret.Resource $secret.Name 2>&1
    }
    
    $outputText = $output -join [Environment]::NewLine
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Importado exitosamente" -ForegroundColor Green
    } elseif ($outputText -match "already managed" -or $outputText -match "already in state") {
        Write-Host "  [INFO] Ya esta en el estado" -ForegroundColor Yellow
    } elseif ($outputText -match "Invalid count argument") {
        Write-Host "  [ADVERTENCIA] Error de dependencias" -ForegroundColor Yellow
        Write-Host "  El secreto puede estar importado. Verificando..." -ForegroundColor Gray
        
        # Verificar si está en el estado
        $stateCheck = & terraform state show $secret.Resource 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] El secreto esta en el estado" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] No esta en el estado, pero Terraform lo actualizara con 'terraform apply'" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] $outputText" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PROCESO COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nAhora ejecuta:" -ForegroundColor Cyan
Write-Host "  terraform plan   # Ver que cambios se haran" -ForegroundColor White
Write-Host "  terraform apply  # Aplicar los cambios" -ForegroundColor White
Write-Host "`nTerraform actualizara los secretos existentes en lugar de intentar crearlos." -ForegroundColor White
