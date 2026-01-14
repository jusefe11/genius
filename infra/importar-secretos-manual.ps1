# Script para importar secretos manualmente
# Ejecuta los comandos de importacion uno por uno

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Importacion Manual de Secretos" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
Set-Location $devPath

Write-Host "IMPORTANTE: Debido a dependencias, necesitamos importar los secretos" -ForegroundColor Yellow
Write-Host "usando comandos individuales. Ejecuta estos comandos en orden:`n" -ForegroundColor White

Write-Host "COMANDO 1: Importar secreto de BD" -ForegroundColor Cyan
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.db_credentials[0]' 'genius/dev/database/credentials'`n" -ForegroundColor Gray

Write-Host "COMANDO 2: Importar secreto de API Keys" -ForegroundColor Cyan
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.api_keys[0]' 'genius/dev/app/api-keys'`n" -ForegroundColor Gray

Write-Host "COMANDO 3: Importar secreto JWT (sintaxis especial para for_each)" -ForegroundColor Cyan
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"jwt_secret\"]' 'genius/dev/app/jwt_secret'`n" -ForegroundColor Gray

Write-Host "COMANDO 4: Importar secreto encryption_key (sintaxis especial para for_each)" -ForegroundColor Cyan
Write-Host "terraform import 'module.secrets_manager.aws_secretsmanager_secret.app_secrets[\"encryption_key\"]' 'genius/dev/app/encryption_key'`n" -ForegroundColor Gray

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SOLUCION ALTERNATIVA (MAS SIMPLE)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si los comandos de importacion fallan por dependencias," -ForegroundColor White
Write-Host "puedes usar esta solucion alternativa:" -ForegroundColor White
Write-Host ""
Write-Host "1. Elimina los secretos existentes (si no necesitas el contenido):" -ForegroundColor Yellow
Write-Host "   cd infra" -ForegroundColor Gray
Write-Host "   .\gestionar-secretos-eliminados.ps1" -ForegroundColor Gray
Write-Host "   # Selecciona opcion 2: Forzar eliminacion inmediata" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Espera 30-60 segundos" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Ejecuta terraform apply:" -ForegroundColor Yellow
Write-Host "   terraform apply" -ForegroundColor Gray
Write-Host ""
Write-Host "Esto creara los secretos desde cero con los valores de terraform.tfvars" -ForegroundColor White
