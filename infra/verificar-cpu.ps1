# Script para verificar que la carga de CPU esta funcionando

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verificacion de Carga de CPU" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    exit 1
}

Set-Location $devPath

# 1. Obtener instancias
Write-Host "1. Obteniendo instancias EC2..." -ForegroundColor Yellow
try {
    $instancesOutput = & aws ec2 describe-instances `
        --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
        --query 'Reservations[*].Instances[*].[InstanceId]' `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $instances = ($instancesOutput -join "`n") | ConvertFrom-Json
        if ($instances.Count -eq 0) {
            Write-Host "   ERROR No se encontraron instancias" -ForegroundColor Red
            exit 1
        }
        $instanceId = $instances[0][0]
        Write-Host "   OK Instancia: $instanceId" -ForegroundColor Green
    } else {
        Write-Host "   ERROR No se pudieron obtener instancias" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 2. Verificar si stress-ng esta corriendo
Write-Host "2. Verificando si stress-ng esta corriendo..." -ForegroundColor Yellow
try {
    $checkOutput = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['ps aux | grep stress-ng | grep -v grep']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $checkResult = ($checkOutput -join "`n") | ConvertFrom-Json
        $commandId = $checkResult.Command.CommandId
        Write-Host "   Comando enviado. Esperando resultado..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
        
        $statusOutput = & aws ssm get-command-invocation `
            --command-id $commandId `
            --instance-id $instanceId `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $status = ($statusOutput -join "`n") | ConvertFrom-Json
            if ($status.Status -eq "Success") {
                $output = $status.StandardOutputContent
                if ($output -and $output.Trim() -ne "") {
                    Write-Host "   OK stress-ng esta corriendo:" -ForegroundColor Green
                    Write-Host "   $output" -ForegroundColor White
                } else {
                    Write-Host "   ADV stress-ng NO esta corriendo" -ForegroundColor Yellow
                    Write-Host "   El proceso puede haber terminado o no se inicio correctamente" -ForegroundColor Yellow
                }
            } else {
                Write-Host "   ERROR Comando fallo: $($status.Status)" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 3. Verificar uso de CPU actual en la instancia
Write-Host "3. Verificando uso de CPU actual en la instancia..." -ForegroundColor Yellow
try {
    $cpuCheckOutput = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['top -bn1 | grep \"Cpu(s)\" | awk \"{print \\$2}\" | cut -d\"%\" -f1']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $cpuCheckResult = ($cpuCheckOutput -join "`n") | ConvertFrom-Json
        $cpuCommandId = $cpuCheckResult.Command.CommandId
        Start-Sleep -Seconds 3
        
        $cpuStatusOutput = & aws ssm get-command-invocation `
            --command-id $cpuCommandId `
            --instance-id $instanceId `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $cpuStatus = ($cpuStatusOutput -join "`n") | ConvertFrom-Json
            if ($cpuStatus.Status -eq "Success") {
                $cpuValue = $cpuStatus.StandardOutputContent.Trim()
                Write-Host "   CPU actual: $cpuValue%" -ForegroundColor $(if ([double]$cpuValue -gt 80) { "Red" } elseif ([double]$cpuValue -gt 50) { "Yellow" } else { "Green" })
            }
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 4. Verificar metricas de CloudWatch
Write-Host "4. Verificando metricas de CPU en CloudWatch (ultimos 15 minutos)..." -ForegroundColor Yellow
try {
    $asgOutput = & terraform output -raw autoscaling_group_name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $asgName = ($asgOutput -join "`n").Trim()
        Write-Host "   ASG Name: $asgName" -ForegroundColor Gray
        
        $startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        
        $metricOutput = & aws cloudwatch get-metric-statistics `
            --namespace "AWS/EC2" `
            --metric-name "CPUUtilization" `
            --dimensions "Name=AutoScalingGroupName,Value=$asgName" `
            --start-time $startTime `
            --end-time $endTime `
            --period 300 `
            --statistics Average `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $metric = ($metricOutput -join "`n") | ConvertFrom-Json
            if ($metric.Datapoints.Count -gt 0) {
                Write-Host "   OK Metricas encontradas: $($metric.Datapoints.Count) puntos" -ForegroundColor Green
                $metric.Datapoints | Sort-Object Timestamp | ForEach-Object {
                    $timestamp = [DateTime]::Parse($_.Timestamp)
                    $cpuValue = [math]::Round($_.Average, 2)
                    $color = if ($cpuValue -gt 80) { "Red" } elseif ($cpuValue -gt 50) { "Yellow" } else { "Green" }
                    Write-Host "      - $($timestamp.ToString('HH:mm:ss')): $cpuValue%" -ForegroundColor $color
                }
            } else {
                Write-Host "   ADV No hay metricas en los ultimos 15 minutos" -ForegroundColor Yellow
                Write-Host "   Esto puede ser normal si:" -ForegroundColor Gray
                Write-Host "     - Acabas de iniciar la carga (espera 5 minutos)" -ForegroundColor Gray
                Write-Host "     - Las metricas aun no se han propagado" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ERROR No se pudieron obtener metricas" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 5. Verificar estado de la alarma
Write-Host "5. Verificando estado de la alarma de CPU..." -ForegroundColor Yellow
try {
    $alarmOutput = & aws cloudwatch describe-alarms `
        --alarm-names "genius-dev-high-cpu" `
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
            Write-Host "   Umbral: $($alarm.Threshold)% durante $($alarm.EvaluationPeriods * $alarm.Period / 60) minutos" -ForegroundColor Gray
        } else {
            Write-Host "   ERROR Alarma no encontrada" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 6. Recomendaciones
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recomendaciones" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si no ves cambios en el dashboard:" -ForegroundColor Yellow
Write-Host "  1. Espera 5-10 minutos (las metricas se actualizan cada 5 minutos)" -ForegroundColor White
Write-Host "  2. Verifica que stress-ng este corriendo (paso 2)" -ForegroundColor White
Write-Host "  3. Verifica que el ASG tenga instancias activas" -ForegroundColor White
Write-Host "  4. Cambia el periodo de tiempo en el dashboard a 1h o 3h" -ForegroundColor White
Write-Host "  5. Verifica que la dimension del dashboard coincida con el ASG" -ForegroundColor White
Write-Host ""
Write-Host "Para reiniciar la carga de CPU:" -ForegroundColor Cyan
Write-Host "  .\test-metrics.ps1" -ForegroundColor White
Write-Host "  Selecciona opcion 3" -ForegroundColor White
Write-Host ""
Write-Host "Para detener la carga de CPU:" -ForegroundColor Cyan
Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
Write-Host ""
