# Script de diagnostico para verificar por que no aparecen metricas en el dashboard

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Diagnostico de Dashboard CloudWatch" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    exit 1
}

Set-Location $devPath

# 1. Verificar que hay instancias en el ASG
Write-Host "1. Verificando instancias en el ASG..." -ForegroundColor Yellow
try {
    $asgOutput = & terraform output -raw autoscaling_group_name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $asgName = ($asgOutput -join "`n").Trim()
        Write-Host "   ASG Name: $asgName" -ForegroundColor White
        
        $instancesOutput = & aws autoscaling describe-auto-scaling-groups `
            --auto-scaling-group-names $asgName `
            --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $instances = ($instancesOutput -join "`n") | ConvertFrom-Json
            if ($instances.Count -gt 0) {
                Write-Host "   OK Instancias encontradas: $($instances.Count)" -ForegroundColor Green
                $instances | ForEach-Object {
                    Write-Host "      - $($_[0]): $($_[1]) / $($_[2])" -ForegroundColor Gray
                }
            } else {
                Write-Host "   ERROR No hay instancias en el ASG" -ForegroundColor Red
                Write-Host "   Esto es la causa principal: Sin instancias = Sin metricas" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ERROR No se pudo consultar el ASG" -ForegroundColor Red
        }
    } else {
        Write-Host "   ERROR No se pudo obtener el nombre del ASG" -ForegroundColor Red
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 2. Verificar Target Group y health checks
Write-Host "2. Verificando Target Group y health checks..." -ForegroundColor Yellow
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
                Write-Host "      - Saludables: $healthy" -ForegroundColor Green
                Write-Host "      - No saludables: $unhealthy" -ForegroundColor $(if ($unhealthy -gt 0) { "Red" } else { "Gray" })
                
                $tgHealth | ForEach-Object {
                    $color = if ($_[1] -eq "healthy") { "Green" } else { "Red" }
                    Write-Host "      - $($_[0]): $($_[1]) $($_[2])" -ForegroundColor $color
                }
            } else {
                Write-Host "   ERROR No hay targets registrados en el Target Group" -ForegroundColor Red
                Write-Host "   Esto impide que aparezcan metricas de HealthyHostCount" -ForegroundColor Yellow
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

# 3. Verificar que el dashboard existe
Write-Host "3. Verificando que el dashboard existe..." -ForegroundColor Yellow
try {
    $dashboardOutput = & aws cloudwatch get-dashboard `
        --dashboard-name "genius-dev-application-status" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   OK Dashboard existe" -ForegroundColor Green
    } else {
        Write-Host "   ERROR Dashboard no encontrado" -ForegroundColor Red
        Write-Host "   Necesitas ejecutar: terraform apply" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 4. Verificar metricas directamente (ultimos 15 minutos)
Write-Host "4. Verificando metricas directamente (ultimos 15 minutos)..." -ForegroundColor Yellow

# Obtener ALB ARN
try {
    $albArnOutput = & terraform output -raw alb_arn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $albArn = ($albArnOutput -join "`n").Trim()
        $albName = ($albArn -split "/")[-1]
        
        # HealthyHostCount
        Write-Host "   Consultando HealthyHostCount..." -ForegroundColor Gray
        $startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        
        $tgIdentifier = ($tgArn -split ":")[5]
        
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
                Write-Host "   OK HealthyHostCount tiene datos: $($healthyMetric.Datapoints.Count) puntos" -ForegroundColor Green
                $healthyMetric.Datapoints | ForEach-Object {
                    Write-Host "      - $($_.Timestamp): $($_.Average)" -ForegroundColor Gray
                }
            } else {
                Write-Host "   ADV HealthyHostCount: No hay datos en los ultimos 15 minutos" -ForegroundColor Yellow
                Write-Host "      Esto puede ser normal si no has generado trafico recientemente" -ForegroundColor Gray
            }
        }
        
        # CPUUtilization
        Write-Host "   Consultando CPUUtilization..." -ForegroundColor Gray
        $cpuMetricOutput = & aws cloudwatch get-metric-statistics `
            --namespace "AWS/EC2" `
            --metric-name "CPUUtilization" `
            --dimensions "Name=AutoScalingGroupName,Value=$asgName" `
            --start-time $startTime `
            --end-time $endTime `
            --period 300 `
            --statistics Average `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $cpuMetric = ($cpuMetricOutput -join "`n") | ConvertFrom-Json
            if ($cpuMetric.Datapoints.Count -gt 0) {
                Write-Host "   OK CPUUtilization tiene datos: $($cpuMetric.Datapoints.Count) puntos" -ForegroundColor Green
                $cpuMetric.Datapoints | ForEach-Object {
                    Write-Host "      - $($_.Timestamp): $($_.Average)%" -ForegroundColor Gray
                }
            } else {
                Write-Host "   ADV CPUUtilization: No hay datos en los ultimos 15 minutos" -ForegroundColor Yellow
            }
        }
        
        # HTTPCode_Target_5XX_Count
        Write-Host "   Consultando HTTPCode_Target_5XX_Count..." -ForegroundColor Gray
        $error5xxOutput = & aws cloudwatch get-metric-statistics `
            --namespace "AWS/ApplicationELB" `
            --metric-name "HTTPCode_Target_5XX_Count" `
            --dimensions "Name=LoadBalancer,Value=$albName" `
            --start-time $startTime `
            --end-time $endTime `
            --period 300 `
            --statistics Sum `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $error5xxMetric = ($error5xxOutput -join "`n") | ConvertFrom-Json
            if ($error5xxMetric.Datapoints.Count -gt 0) {
                Write-Host "   OK HTTPCode_Target_5XX_Count tiene datos: $($error5xxMetric.Datapoints.Count) puntos" -ForegroundColor Green
                $error5xxMetric.Datapoints | ForEach-Object {
                    Write-Host "      - $($_.Timestamp): $($_.Sum)" -ForegroundColor Gray
                }
            } else {
                Write-Host "   ADV HTTPCode_Target_5XX_Count: No hay datos (normal si no hay errores)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 5. Resumen y recomendaciones
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resumen y Recomendaciones" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CAUSAS COMUNES si no ves metricas:" -ForegroundColor Yellow
Write-Host "  1. No hay instancias en el ASG" -ForegroundColor White
Write-Host "  2. No hay targets registrados en el Target Group" -ForegroundColor White
Write-Host "  3. No has generado suficiente trafico (espera 2-5 minutos)" -ForegroundColor White
Write-Host "  4. El periodo de tiempo en el dashboard es muy corto" -ForegroundColor White
Write-Host "  5. Las dimensiones del dashboard no coinciden con las metricas" -ForegroundColor White
Write-Host ""
Write-Host "SOLUCIONES:" -ForegroundColor Yellow
Write-Host "  1. Verifica que el ASG tenga instancias: aws autoscaling describe-auto-scaling-groups" -ForegroundColor White
Write-Host "  2. Genera trafico con el script test-metrics.ps1" -ForegroundColor White
Write-Host "  3. Espera 2-5 minutos y actualiza el dashboard (F5)" -ForegroundColor White
Write-Host "  4. Cambia el periodo de tiempo en CloudWatch a 1h o 3h" -ForegroundColor White
Write-Host "  5. Verifica las dimensiones en el dashboard vs las metricas reales" -ForegroundColor White
Write-Host ""
