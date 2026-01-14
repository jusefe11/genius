# Script que ejecuta terraform apply de forma segura, limpiando secretos eliminados primero
# Uso: .\terraform-apply-seguro.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Terraform Apply Seguro" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la carpeta infra/" -ForegroundColor Yellow
    exit 1
}

Set-Location $devPath

Write-Host "PASO 1: Limpiando secretos eliminados..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot "limpiar-secretos-antes-apply.ps1") | Out-Null

Write-Host "`nPASO 2: Ejecutando terraform apply...`n" -ForegroundColor Yellow
& terraform apply
