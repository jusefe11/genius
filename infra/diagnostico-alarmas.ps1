# Script de diagnostico para las alarmas de CloudWatch
# Verifica por que las alarmas no se activan

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostico de Alarmas CloudWatch" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Funcion para obtener instancias
function Get-EC2Instances {
    Write-Host "Obteniendo instancias EC2..." -ForegroundColor Yellow
    try {
        $instancesOutput = & aws ec2 describe-instances `
            --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
            --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $instancesJson = $instancesOutput -join "`n"
            $instances = $instancesJson | ConvertFrom-Json
            if ($instances.Count -gt 0) {
                Write-Host "OK Instancias encontradas: $($instances.Count)" -ForegroundColor Green
                return $instances
            } else {
                Write-Host "ERROR No se encontraron instancias" -ForegroundColor Red
                return $null
            }
        } else {
            Write-Host "ERROR Error al obtener instancias" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "ERROR Error: $_" -ForegroundColor Red
        return $null
    }
}

# Funcion para verificar estado de alarma
function Check-Alarm {
    param([string]$alarmName)
    Write-Host "`nVerificando alarma: $alarmName" -ForegroundColor Yellow
    try {
        $alarmOutput = & aws cloudwatch describe-alarms --alarm-names $alarmName --query 'MetricAlarms[0]' --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
            if ($alarm) {
                Write-Host "  Estado: $($alarm.StateValue)" -ForegroundColor $(if ($alarm.StateValue -eq "ALARM") { "Red" } else { "Green" })
                Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                Write-Host "  Threshold: $($alarm.Threshold)" -ForegroundColor Gray
                Write-Host "  ComparisonOperator: $($alarm.ComparisonOperator)" -ForegroundColor Gray
                Write-Host "  TreatMissingData: $($alarm.TreatMissingData)" -ForegroundColor Gray
                Write-Host "  Period: $($alarm.Period) segundos" -ForegroundColor Gray
                Write-Host "  EvaluationPeriods: $($alarm.EvaluationPeriods)" -ForegroundColor Gray
                return $alarm
            } else {
                Write-Host "  ERROR Alarma no encontrada" -ForegroundColor Red
                return $null
            }
        } else {
            Write-Host "  ERROR No se pudo consultar la alarma" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        return $null
    }
}

# Funcion para verificar metricas recientes
function Check-Metrics {
    param(
        [string]$Namespace,
        [string]$MetricName,
        [string]$DimensionName,
        [string]$DimensionValue
    )
    Write-Host "`nVerificando metricas: $Namespace/$MetricName" -ForegroundColor Yellow
    Write-Host "  Dimension: $DimensionName = $DimensionValue" -ForegroundColor Gray
    
    try {
        $endTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        $startTime = (Get-Date).AddHours(-3).ToString("yyyy-MM-ddTHH:mm:ss")
        
        $metricsOutput = & aws cloudwatch get-metric-statistics `
            --namespace $Namespace `
            --metric-name $MetricName `
            --dimensions Name=$DimensionName,Value=$DimensionValue `
            --start-time $startTime `
            --end-time $endTime `
            --period 60 `
            --statistics Sum `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $metrics = ($metricsOutput -join "`n") | ConvertFrom-Json
            if ($metrics.Datapoints.Count -gt 0) {
                Write-Host "  OK Se encontraron $($metrics.Datapoints.Count) puntos de datos" -ForegroundColor Green
                $latest = $metrics.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 1
                Write-Host "  Ultimo valor: $($latest.Sum) a las $($latest.Timestamp)" -ForegroundColor White
                return $metrics
            } else {
                Write-Host "  ERROR No hay puntos de datos disponibles" -ForegroundColor Red
                return $null
            }
        } else {
            Write-Host "  ERROR Error al consultar metricas: $metricsOutput" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        return $null
    }
}

# Obtener ASG name
Write-Host "Obteniendo nombre del ASG..." -ForegroundColor Yellow
try {
    $asgOutput = & aws autoscaling describe-auto-scaling-groups `
        --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `genius-dev`)].AutoScalingGroupName' `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $asgNames = ($asgOutput -join "`n") | ConvertFrom-Json
        if ($asgNames.Count -gt 0) {
            $asgName = $asgNames[0]
            Write-Host "OK ASG encontrado: $asgName" -ForegroundColor Green
        } else {
            Write-Host "ERROR No se encontro ASG" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR Error al obtener ASG" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}

# 1. Verificar alarmas
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "1. ESTADO DE LAS ALARMAS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$cpuAlarm = Check-Alarm "genius-dev-high-cpu"
$dockerAlarm = Check-Alarm "genius-dev-docker-containers-down"

# 2. Verificar metricas de Docker
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "2. METRICAS DE DOCKER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$dockerMetrics = Check-Metrics -Namespace "Docker/Containers" -MetricName "RunningContainers" -DimensionName "AutoScalingGroupName" -DimensionValue $asgName

# 3. Verificar instancias y script de monitoreo
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "3. VERIFICACION EN INSTANCIAS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$instances = Get-EC2Instances
if ($instances) {
    $instanceId = $instances[0][0]
    Write-Host "`nVerificando en instancia: $instanceId" -ForegroundColor Yellow
    
    # Verificar si el script existe
    Write-Host "`nVerificando script de monitoreo..." -ForegroundColor Yellow
    $scriptCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['test -f /usr/local/bin/monitor-docker-containers.sh && echo EXISTS || echo NOT_FOUND']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $scriptResult = ($scriptCheck -join "`n") | ConvertFrom-Json
        $commandId = $scriptResult.Command.CommandId
        $scriptOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        if ($scriptOutput.StandardOutputContent -like "*EXISTS*") {
            Write-Host "  OK Script existe" -ForegroundColor Green
        } else {
            Write-Host "  ERROR Script no existe" -ForegroundColor Red
        }
    }
    
    # Verificar cron job
    Write-Host "`nVerificando cron job..." -ForegroundColor Yellow
    $cronCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['grep monitor-docker-containers /etc/crontab || echo NOT_FOUND']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $cronResult = ($cronCheck -join "`n") | ConvertFrom-Json
        $commandId = $cronResult.Command.CommandId
        $cronOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        if ($cronOutput.StandardOutputContent -notlike "*NOT_FOUND*") {
            Write-Host "  OK Cron job configurado" -ForegroundColor Green
            Write-Host "  $($cronOutput.StandardOutputContent)" -ForegroundColor Gray
        } else {
            Write-Host "  ERROR Cron job no encontrado" -ForegroundColor Red
        }
    }
    
    # Verificar contenedores Docker
    Write-Host "`nVerificando contenedores Docker..." -ForegroundColor Yellow
    $dockerCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['sudo docker ps -q | wc -l']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $dockerResult = ($dockerCheck -join "`n") | ConvertFrom-Json
        $commandId = $dockerResult.Command.CommandId
        $dockerOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "  Contenedores corriendo: $($dockerOutput.StandardOutputContent.Trim())" -ForegroundColor White
    }
    
    # Ejecutar script manualmente y verificar logs
    Write-Host "`nEjecutando script de monitoreo manualmente..." -ForegroundColor Yellow
    $manualRun = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh 2>&1']" `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $manualResult = ($manualRun -join "`n") | ConvertFrom-Json
        $commandId = $manualResult.Command.CommandId
        $manualOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "  Salida del script:" -ForegroundColor White
        Write-Host "  $($manualOutput.StandardOutputContent)" -ForegroundColor Gray
        if ($manualOutput.StandardErrorContent) {
            Write-Host "  Errores:" -ForegroundColor Red
            Write-Host "  $($manualOutput.StandardErrorContent)" -ForegroundColor Red
        }
    }
}

# 4. Resumen y recomendaciones
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "4. RESUMEN Y RECOMENDACIONES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not $dockerMetrics) {
    Write-Host "`nPROBLEMA: No hay metricas de Docker en CloudWatch" -ForegroundColor Red
    Write-Host "POSIBLES CAUSAS:" -ForegroundColor Yellow
    Write-Host "  1. El script monitor-docker-containers.sh no se esta ejecutando" -ForegroundColor White
    Write-Host "  2. El cron job no esta configurado correctamente" -ForegroundColor White
    Write-Host "  3. Error al enviar metricas (verificar permisos IAM)" -ForegroundColor White
    Write-Host "  4. El script tiene errores (verificar logs)" -ForegroundColor White
    Write-Host "`nSOLUCION:" -ForegroundColor Yellow
    Write-Host "  - Verificar logs: /var/log/docker-monitor.log" -ForegroundColor White
    Write-Host "  - Ejecutar script manualmente para ver errores" -ForegroundColor White
    Write-Host "  - Verificar que el cron job este activo" -ForegroundColor White
}

if ($dockerAlarm -and $dockerAlarm.StateValue -ne "ALARM" -and -not $dockerMetrics) {
    Write-Host "`nPROBLEMA: La alarma deberia estar en ALARM con treat_missing_data=breaching" -ForegroundColor Red
    Write-Host "SOLUCION:" -ForegroundColor Yellow
    Write-Host "  - Verificar que la alarma se haya aplicado correctamente con Terraform" -ForegroundColor White
    Write-Host "  - La alarma puede tardar unos minutos en evaluarse" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnostico completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
