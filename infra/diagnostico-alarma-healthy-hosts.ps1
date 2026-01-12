# Script para diagnosticar por que la alarma no-healthy-hosts esta en ALARM

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Diagnostico: Alarma No Healthy Hosts" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    exit 1
}

Set-Location $devPath

# 1. Verificar Target Group y health checks
Write-Host "1. Verificando Target Group y health checks..." -ForegroundColor Yellow
try {
    $tgArnOutput = & terraform output -raw target_group_arn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tgArn = ($tgArnOutput -join "`n").Trim()
        Write-Host "   Target Group ARN: $tgArn" -ForegroundColor White
        
        $tgHealthOutput = & aws elbv2 describe-target-health `
            --target-group-arn $tgArn `
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $tgHealth = ($tgHealthOutput -join "`n") | ConvertFrom-Json
            if ($tgHealth.Count -gt 0) {
                Write-Host "   OK Targets registrados: $($tgHealth.Count)" -ForegroundColor Green
                $healthy = ($tgHealth | Where-Object { $_[1] -eq "healthy" }).Count
                $unhealthy = ($tgHealth | Where-Object { $_[1] -ne "healthy" }).Count
                Write-Host "      - Saludables: $healthy" -ForegroundColor $(if ($healthy -gt 0) { "Green" } else { "Red" })
                Write-Host "      - No saludables: $unhealthy" -ForegroundColor $(if ($unhealthy -gt 0) { "Red" } else { "Gray" })
                
                $tgHealth | ForEach-Object {
                    $color = if ($_[1] -eq "healthy") { "Green" } else { "Red" }
                    Write-Host "      - $($_[0]): $($_[1]) $($_[2])" -ForegroundColor $color
                }
                
                if ($healthy -eq 0) {
                    Write-Host "`n   PROBLEMA: No hay hosts saludables!" -ForegroundColor Red
                    Write-Host "   Esto explica por que la alarma esta en ALARM" -ForegroundColor Yellow
                }
            } else {
                Write-Host "   ERROR No hay targets registrados en el Target Group" -ForegroundColor Red
                Write-Host "   Esto explica por que no hay metricas y la alarma esta en ALARM" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ERROR No se pudo consultar el health del Target Group" -ForegroundColor Red
        }
    } else {
        Write-Host "   ERROR No se pudo obtener el ARN del Target Group" -ForegroundColor Red
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 2. Verificar metricas de HealthyHostCount
Write-Host "2. Verificando metricas de HealthyHostCount (ultimos 15 minutos)..." -ForegroundColor Yellow
try {
    $albArnOutput = & terraform output -raw alb_arn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $albArn = ($albArnOutput -join "`n").Trim()
        $albName = ($albArn -split "/")[-1]
        $tgIdentifier = ($tgArn -split ":")[5]
        
        $startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        
        $healthyMetricOutput = & aws cloudwatch get-metric-statistics `
            --namespace "AWS/ApplicationELB" `
            --metric-name "HealthyHostCount" `
            --dimensions "Name=TargetGroup,Value=$tgIdentifier" "Name=LoadBalancer,Value=$albName" `
            --start-time $startTime `
            --end-time $endTime `
            --period 60 `
            --statistics Average `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $healthyMetric = ($healthyMetricOutput -join "`n") | ConvertFrom-Json
            if ($healthyMetric.Datapoints.Count -gt 0) {
                Write-Host "   OK Metricas encontradas: $($healthyMetric.Datapoints.Count) puntos" -ForegroundColor Green
                $healthyMetric.Datapoints | Sort-Object Timestamp | ForEach-Object {
                    $timestamp = [DateTime]::Parse($_.Timestamp)
                    $value = [math]::Round($_.Average, 2)
                    $color = if ($value -ge 1) { "Green" } else { "Red" }
                    Write-Host "      - $($timestamp.ToString('HH:mm:ss')): $value hosts saludables" -ForegroundColor $color
                }
            } else {
                Write-Host "   ERROR No hay metricas en los ultimos 15 minutos" -ForegroundColor Red
                Write-Host "   Esto explica por que la alarma esta en ALARM" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Posibles causas:" -ForegroundColor Yellow
                Write-Host "     1. No hay targets registrados en el Target Group" -ForegroundColor White
                Write-Host "     2. No hay trafico hacia el ALB (sin trafico = sin metricas)" -ForegroundColor White
                Write-Host "     3. Las dimensiones de la alarma no coinciden con las metricas" -ForegroundColor White
            }
        } else {
            Write-Host "   ERROR No se pudieron obtener metricas" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 3. Verificar estado de la alarma
Write-Host "3. Verificando estado de la alarma..." -ForegroundColor Yellow
try {
    $alarmOutput = & aws cloudwatch describe-alarms `
        --alarm-names "genius-dev-no-healthy-hosts" `
        --query 'MetricAlarms[0]' `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
        if ($alarm) {
            $state = $alarm.StateValue
            $color = switch ($state) {
                "OK" { "Green" }
                "ALARM" { "Red" }
                default { "Yellow" }
            }
            Write-Host "   Estado: $state" -ForegroundColor $color
            Write-Host "   Razon: $($alarm.StateReason)" -ForegroundColor Gray
            Write-Host "   Umbral: HealthyHostCount < 1" -ForegroundColor Gray
            Write-Host "   Treat Missing Data: $($alarm.TreatMissingData)" -ForegroundColor Gray
            
            if ($alarm.TreatMissingData -eq "breaching") {
                Write-Host "`n   ADVERTENCIA: treat_missing_data = 'breaching'" -ForegroundColor Yellow
                Write-Host "   Esto significa que cuando no hay datos, se trata como ALARM" -ForegroundColor Yellow
                Write-Host "   Se recomienda cambiar a 'notBreaching' para evitar falsos positivos" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ERROR Alarma no encontrada" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 4. Verificar instancias en el ASG
Write-Host "4. Verificando instancias en el ASG..." -ForegroundColor Yellow
try {
    $asgOutput = & terraform output -raw autoscaling_group_name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $asgName = ($asgOutput -join "`n").Trim()
        
        $instancesOutput = & aws autoscaling describe-auto-scaling-groups `
            --auto-scaling-group-names $asgName `
            --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $instances = ($instancesOutput -join "`n") | ConvertFrom-Json
            if ($instances.Count -gt 0) {
                Write-Host "   OK Instancias en el ASG: $($instances.Count)" -ForegroundColor Green
                $instances | ForEach-Object {
                    Write-Host "      - $($_[0]): $($_[1]) / $($_[2])" -ForegroundColor Gray
                }
            } else {
                Write-Host "   ERROR No hay instancias en el ASG" -ForegroundColor Red
                Write-Host "   Esto explica por que no hay hosts saludables" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 5. Recomendaciones
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recomendaciones" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si la alarma esta en ALARM:" -ForegroundColor Yellow
Write-Host "  1. Verifica que hay instancias en el ASG (paso 4)" -ForegroundColor White
Write-Host "  2. Verifica que hay targets registrados en el Target Group (paso 1)" -ForegroundColor White
Write-Host "  3. Verifica que los targets estan 'healthy' (paso 1)" -ForegroundColor White
Write-Host "  4. Genera trafico hacia el ALB para activar metricas:" -ForegroundColor White
Write-Host "     .\test-metrics.ps1" -ForegroundColor Gray
Write-Host "     Selecciona opcion 1" -ForegroundColor Gray
Write-Host "  5. Espera 2-5 minutos para que las metricas se actualicen" -ForegroundColor White
Write-Host ""
Write-Host "Si no hay targets registrados:" -ForegroundColor Yellow
Write-Host "  - Las instancias del ASG deben registrarse automaticamente en el Target Group" -ForegroundColor White
Write-Host "  - Verifica que el ASG esta configurado correctamente" -ForegroundColor White
Write-Host ""
Write-Host "Si hay targets pero no estan 'healthy':" -ForegroundColor Yellow
Write-Host "  - Verifica que el health check endpoint esta funcionando" -ForegroundColor White
Write-Host "  - Verifica que el puerto y path del health check son correctos" -ForegroundColor White
Write-Host ""
