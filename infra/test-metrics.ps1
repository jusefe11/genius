# Script para probar las métricas de CloudWatch
# Genera tráfico hacia el ALB para activar las métricas

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Prueba de Métricas CloudWatch" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontró el directorio envs\dev" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la carpeta infra/" -ForegroundColor Yellow
    exit 1
}

Set-Location $devPath

# Obtener la URL del ALB
Write-Host "Obteniendo URL del ALB..." -ForegroundColor Yellow
try {
    $albDns = terraform output -raw alb_dns_name 2>$null
    if (-not $albDns) {
        Write-Host "Error: No se pudo obtener la URL del ALB" -ForegroundColor Red
        Write-Host "Asegúrate de que Terraform esté inicializado y que el ALB esté desplegado" -ForegroundColor Yellow
        exit 1
    }
    
    $albUrl = "http://$albDns"
    Write-Host "✓ URL del ALB: $albUrl" -ForegroundColor Green
} catch {
    Write-Host "Error al obtener la URL del ALB: $_" -ForegroundColor Red
    exit 1
}

# Verificar conectividad
Write-Host "`nVerificando conectividad..." -ForegroundColor Yellow
try {
    $testResponse = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 10
    Write-Host "✓ Conectividad OK - Status: $($testResponse.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "⚠ Advertencia: No se pudo conectar al ALB: $_" -ForegroundColor Yellow
    Write-Host "Continuando de todas formas para generar tráfico..." -ForegroundColor Yellow
}

# Preguntar cuántas peticiones hacer
Write-Host "`n¿Cuántas peticiones quieres generar? (recomendado: 50)" -ForegroundColor Cyan
$numRequests = Read-Host "Número de peticiones"
if (-not $numRequests -or $numRequests -eq "") {
    $numRequests = 50
} else {
    $numRequests = [int]$numRequests
}

# Generar tráfico
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Generando $numRequests peticiones..." -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

$successCount = 0
$errorCount = 0

for ($i = 1; $i -le $numRequests; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 5
        Write-Host "✓ [$i/$numRequests] Status: $($response.StatusCode)" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "✗ [$i/$numRequests] Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
    
    # Esperar entre peticiones (excepto la última)
    if ($i -lt $numRequests) {
        Start-Sleep -Milliseconds 500
    }
}

# Resumen
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Resumen" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Peticiones exitosas: $successCount" -ForegroundColor Green
Write-Host "Peticiones fallidas: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Gray" })
Write-Host "Total: $numRequests" -ForegroundColor Cyan

# Mostrar instrucciones
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Próximos pasos" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Espera 2-5 minutos para que las métricas se actualicen" -ForegroundColor Yellow
Write-Host "2. Ve a CloudWatch → Panels → Dashboards" -ForegroundColor Yellow
Write-Host "3. Abre el dashboard: genius-dev-application-status" -ForegroundColor Yellow
Write-Host "4. Actualiza la página (F5) después de esperar" -ForegroundColor Yellow

$dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
Write-Host "`nDashboard URL:" -ForegroundColor Cyan
Write-Host $dashboardUrl -ForegroundColor White

Write-Host "`n¿Quieres abrir el dashboard en tu navegador? (S/N)" -ForegroundColor Cyan
$openBrowser = Read-Host
if ($openBrowser -eq "S" -or $openBrowser -eq "s" -or $openBrowser -eq "Y" -or $openBrowser -eq "y") {
    Start-Process $dashboardUrl
}

Write-Host "`n¡Listo! Revisa CloudWatch en unos minutos." -ForegroundColor Green
