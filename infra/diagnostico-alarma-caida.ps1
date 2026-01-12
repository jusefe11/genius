# Script de diagnostico para verificar por que la alarma no se activa cuando Docker se detiene
# Verifica: instancias, contenedores Docker, health checks del ALB, metricas y estado de la alarma

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Diagnostico: Alarma No Se Activa" -ForegroundColor Cyan
Write-Host "  Cuando Docker se Detiene" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la carpeta infra/" -ForegroundColor Yellow
    exit 1
}

Set-Location $devPath

# 1. Verificar instancias EC2
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "1. VERIFICANDO INSTANCIAS EC2" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
try {
    $instancesOutput = & aws ec2 describe-instances `
        --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $instancesJson = $instancesOutput -join "`n"
        $instances = $instancesJson | ConvertFrom-Json
        if ($instances.Count -gt 0) {
            Write-Host "OK Instancias encontradas: $($instances.Count)" -ForegroundColor Green
            $instances | ForEach-Object {
                Write-Host "  - Instance ID: $($_[0]) - Estado: $($_[1]) - IP: $($_[2])" -ForegroundColor White
            }
            $instanceIds = $instances | ForEach-Object { $_[0] }
        } else {
            Write-Host "ERROR No se encontraron instancias en ejecucion" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR Error al obtener instancias" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR Error: $_" -ForegroundColor Red
    exit 1
}

# 2. Verificar estado de contenedores Docker en cada instancia
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "2. VERIFICANDO CONTENEDORES DOCKER" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
foreach ($instanceId in $instanceIds) {
    Write-Host "`nInstancia: $instanceId" -ForegroundColor Cyan
    try {
        # Verificar contenedores corriendo
        $dockerPsOutput = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['sudo docker ps']" `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerPsResult = ($dockerPsOutput -join "`n") | ConvertFrom-Json
            $dockerPsCommandId = $dockerPsResult.Command.CommandId
            Start-Sleep -Seconds 3
            
            $dockerPsStatusOutput = & aws ssm get-command-invocation `
                --command-id $dockerPsCommandId `
                --instance-id $instanceId `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerPsStatus = ($dockerPsStatusOutput -join "`n") | ConvertFrom-Json
                if ($dockerPsStatus.Status -eq "Success") {
                    $dockerOutput = $dockerPsStatus.StandardOutputContent.Trim()
                    if ($dockerOutput -and $dockerOutput -notlike "*CONTAINER ID*") {
                        Write-Host "  OK Contenedores corriendo:" -ForegroundColor Green
                        Write-Host $dockerOutput -ForegroundColor White
                    } else {
                        Write-Host "  ADVERTENCIA: No hay contenedores Docker corriendo" -ForegroundColor Red
                        Write-Host "  Esto deberia hacer que HealthyHostCount = 0" -ForegroundColor Yellow
                    }
                }
            }
        }
        
        # Verificar contenedores detenidos
        $dockerPsAOutput = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['sudo docker ps -a']" `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerPsAResult = ($dockerPsAOutput -join "`n") | ConvertFrom-Json
            $dockerPsACommandId = $dockerPsAResult.Command.CommandId
            Start-Sleep -Seconds 3
            
            $dockerPsAStatusOutput = & aws ssm get-command-invocation `
                --command-id $dockerPsACommandId `
                --instance-id $instanceId `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerPsAStatus = ($dockerPsAStatusOutput -join "`n") | ConvertFrom-Json
                if ($dockerPsAStatus.Status -eq "Success") {
                    $dockerAOutput = $dockerPsAStatus.StandardOutputContent.Trim()
                    Write-Host "  Todos los contenedores (corriendo y detenidos):" -ForegroundColor Gray
                    Write-Host $dockerAOutput -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "  ERROR Error al verificar Docker: $_" -ForegroundColor Red
    }
}

# 3. Verificar Target Group Health (Health Checks del ALB)
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "3. VERIFICANDO HEALTH CHECKS DEL ALB" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
try {
    # Obtener Target Group ARN desde Terraform
    $tgArnOutput = & terraform output -raw target_group_arn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tgArn = ($tgArnOutput -join "`n").Trim()
        Write-Host "Target Group ARN: $tgArn" -ForegroundColor Gray
        
        # Extraer nombre del Target Group
        $tgName = ($tgArn -split "/")[-1]
        
        # Verificar health de targets
        $healthOutput = & aws elbv2 describe-target-health `
            --target-group-arn $tgArn `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $health = ($healthOutput -join "`n") | ConvertFrom-Json
            Write-Host "`nEstado de Health Checks:" -ForegroundColor Cyan
            foreach ($target in $health.TargetHealthDescriptions) {
                $state = $target.TargetHealth.State
                $color = switch ($state) {
                    "healthy" { "Green" }
                    "unhealthy" { "Red" }
                    "initial" { "Yellow" }
                    "draining" { "Yellow" }
                    default { "Gray" }
                }
                Write-Host "  - Target: $($target.Target.Id):$($target.Target.Port)" -ForegroundColor White
                Write-Host "    Estado: $state" -ForegroundColor $color
                if ($target.TargetHealth.Reason) {
                    Write-Host "    Razon: $($target.TargetHealth.Reason)" -ForegroundColor Gray
                }
                if ($target.TargetHealth.Description) {
                    Write-Host "    Descripcion: $($target.TargetHealth.Description)" -ForegroundColor Gray
                }
            }
            
            $healthyCount = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
            $unhealthyCount = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "unhealthy" }).Count
            Write-Host "`nResumen:" -ForegroundColor Cyan
            Write-Host "  - Hosts saludables: $healthyCount" -ForegroundColor $(if ($healthyCount -gt 0) { "Green" } else { "Red" })
            Write-Host "  - Hosts no saludables: $unhealthyCount" -ForegroundColor $(if ($unhealthyCount -gt 0) { "Red" } else { "Green" })
            
            if ($healthyCount -eq 0) {
                Write-Host "`nIMPORTANTE: No hay hosts saludables - HealthyHostCount deberia ser 0" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR Error al obtener health checks" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR No se pudo obtener Target Group ARN de Terraform" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR Error: $_" -ForegroundColor Red
}

# 4. Verificar metricas de HealthyHostCount directamente
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "4. VERIFICANDO METRICAS DE CLOUDWATCH" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
try {
    # Obtener ALB ARN y Target Group identifier
    $albArnOutput = & terraform output -raw alb_arn 2>&1
    if ($LASTEXITCODE -eq 0) {
        $albArn = ($albArnOutput -join "`n").Trim()
        $albName = ($albArn -split "/")[-1]
        
        $tgArnOutput = & terraform output -raw target_group_arn 2>&1
        if ($LASTEXITCODE -eq 0) {
            $tgArn = ($tgArnOutput -join "`n").Trim()
            $tgIdentifier = ($tgArn -split ":")[5]
            
            Write-Host "Consultando metricas de HealthyHostCount (ultimos 15 minutos)..." -ForegroundColor Cyan
            $endTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            $startTime = (Get-Date).AddMinutes(-15).ToString("yyyy-MM-ddTHH:mm:ss")
            
            $metricsOutput = & aws cloudwatch get-metric-statistics `
                --namespace "AWS/ApplicationELB" `
                --metric-name "HealthyHostCount" `
                --dimensions "Name=TargetGroup,Value=$tgIdentifier" "Name=LoadBalancer,Value=$albName" `
                --start-time $startTime `
                --end-time $endTime `
                --period 60 `
                --statistics Average `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $metrics = ($metricsOutput -join "`n") | ConvertFrom-Json
                if ($metrics.Datapoints.Count -gt 0) {
                    Write-Host "`nMetricas encontradas:" -ForegroundColor Green
                    $metrics.Datapoints | Sort-Object Timestamp | ForEach-Object {
                        $timestamp = [DateTime]::Parse($_.Timestamp).ToString("HH:mm:ss")
                        $value = $_.Average
                        $color = if ($value -eq 0) { "Red" } elseif ($value -ge 1) { "Green" } else { "Yellow" }
                        Write-Host "  - $timestamp : HealthyHostCount = $value" -ForegroundColor $color
                    }
                    
                    $latestMetric = $metrics.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 1
                    Write-Host "`nUltimo valor: HealthyHostCount = $($latestMetric.Average) (a las $([DateTime]::Parse($latestMetric.Timestamp).ToString('HH:mm:ss')))" -ForegroundColor Cyan
                    
                    if ($latestMetric.Average -eq 0) {
                        Write-Host "OK HealthyHostCount es 0 - La alarma DEBERIA activarse" -ForegroundColor Yellow
                    } else {
                        Write-Host "ADVERTENCIA: HealthyHostCount es $($latestMetric.Average) - No es 0" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "ERROR No se encontraron metricas de HealthyHostCount en los ultimos 15 minutos" -ForegroundColor Red
                    Write-Host "Esto puede significar:" -ForegroundColor Yellow
                    Write-Host "  - No hay trafico hacia el ALB" -ForegroundColor White
                    Write-Host "  - Las metricas aun no se han propagado (puede tardar 1-2 minutos)" -ForegroundColor White
                }
            } else {
                Write-Host "ERROR Error al consultar metricas" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "ERROR Error: $_" -ForegroundColor Red
}

# 5. Verificar estado de la alarma
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "5. VERIFICANDO ESTADO DE LA ALARMA" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
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
                "INSUFFICIENT_DATA" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "Estado de la alarma: $state" -ForegroundColor $color
            Write-Host "Razon: $($alarm.StateReason)" -ForegroundColor Gray
            Write-Host "Umbral: HealthyHostCount < 1" -ForegroundColor Gray
            Write-Host "Periodo: $($alarm.Period) segundos" -ForegroundColor Gray
            Write-Host "Evaluaciones: $($alarm.EvaluationPeriods) periodo(s)" -ForegroundColor Gray
            Write-Host "Tratamiento de datos faltantes: $($alarm.TreatMissingData)" -ForegroundColor Gray
            
            if ($state -eq "OK") {
                Write-Host "`nADVERTENCIA: La alarma esta en estado OK pero deberia estar en ALARM" -ForegroundColor Red
                Write-Host "Posibles causas:" -ForegroundColor Yellow
                Write-Host "  1. Las metricas aun no se han actualizado (espera 1-2 minutos mas)" -ForegroundColor White
                Write-Host "  2. HealthyHostCount no es realmente 0 (verifica health checks arriba)" -ForegroundColor White
                Write-Host "  3. El periodo de evaluacion aun no se ha cumplido" -ForegroundColor White
            } elseif ($state -eq "ALARM") {
                Write-Host "`nOK La alarma esta activa (ALARM)" -ForegroundColor Green
            } elseif ($state -eq "INSUFFICIENT_DATA") {
                Write-Host "`nADVERTENCIA: La alarma no tiene suficientes datos" -ForegroundColor Yellow
                Write-Host "Esto puede significar que no hay metricas disponibles" -ForegroundColor White
            }
        } else {
            Write-Host "ERROR Alarma no encontrada" -ForegroundColor Red
            Write-Host "Ejecuta 'terraform apply' para crear la alarma" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ERROR Error al consultar la alarma" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR Error: $_" -ForegroundColor Red
}

# 6. Recomendaciones
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RECOMENDACIONES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si la alarma no se activa:" -ForegroundColor Yellow
Write-Host "  1. Espera 2-3 minutos despues de detener Docker" -ForegroundColor White
Write-Host "  2. Verifica que los health checks del ALB muestren 'unhealthy'" -ForegroundColor White
Write-Host "  3. Genera trafico hacia el ALB para activar las metricas:" -ForegroundColor White
Write-Host "     .\test-metrics.ps1 (opcion 1)" -ForegroundColor Gray
Write-Host "  4. Verifica el dashboard con un rango de tiempo mas amplio (1h o 3h)" -ForegroundColor White
Write-Host "  5. Revisa la configuracion de la alarma en Terraform" -ForegroundColor White
Write-Host ""
Write-Host "Para forzar la activacion de la alarma:" -ForegroundColor Yellow
Write-Host "  - Deten todos los contenedores Docker" -ForegroundColor White
Write-Host "  - Espera 2-3 minutos" -ForegroundColor White
Write-Host "  - Genera trafico hacia el ALB (para que CloudWatch registre las metricas)" -ForegroundColor White
Write-Host "  - Verifica el estado de la alarma nuevamente" -ForegroundColor White
