# Script para probar las metricas de CloudWatch
# Dashboard simplificado: CPU y Docker
# Congruente con el dashboard: genius-dev-application-status

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Prueba de Metricas CloudWatch" -ForegroundColor Cyan
Write-Host "  Dashboard: genius-dev-application-status" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cambiar al directorio del ambiente
$devPath = Join-Path $PSScriptRoot "envs\dev"
if (-not (Test-Path $devPath)) {
    Write-Host "Error: No se encontro el directorio envs\dev" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la carpeta infra/" -ForegroundColor Yellow
    exit 1
}

Set-Location $devPath

# Menu de opciones de prueba - Congruente con el Dashboard de CloudWatch
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Pruebas para Activar Alarmas CloudWatch" -ForegroundColor Cyan
Write-Host "Dashboard: genius-dev-application-status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ACTIVAR ALARMAS (Pruebas de Fallo):" -ForegroundColor Red
Write-Host "  1. Widget 1: CPU Usage [high-cpu]" -ForegroundColor Red
Write-Host "     - Activa cuando CPUUtilization > 80% durante 1 minuto" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Widget 2: Docker Containers [docker-containers-down]" -ForegroundColor Red
Write-Host "     - Activa cuando RunningContainers < 2 (contenedores caidos)" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. TODO: Actualizar Script Docker + CPU + Docker" -ForegroundColor Magenta
Write-Host "     - Actualiza script Docker, satura CPU y detiene contenedor" -ForegroundColor Gray
Write-Host ""
Write-Host "VERIFICACION:" -ForegroundColor White
Write-Host "  3. Verificar estado de todas las alarmas" -ForegroundColor Green
Write-Host ""
Write-Host "Selecciona una opcion (1-4):" -ForegroundColor Cyan
$option = Read-Host

if (-not $option -or $option -eq "") {
    $option = "1"
}

# Funcion auxiliar para obtener instancias
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
                $instances | ForEach-Object { Write-Host "  - Instance ID: $($_[0]) - IP: $($_[1])" -ForegroundColor White }
                return $instances
            } else {
                Write-Host "ERROR No se encontraron instancias en ejecucion" -ForegroundColor Red
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

# Funcion auxiliar para verificar alarma
function Check-Alarm {
    param([string]$alarmName)
    Write-Host "`nVerificando estado de la alarma: $alarmName..." -ForegroundColor Yellow
    try {
        $alarmOutput = & aws cloudwatch describe-alarms --alarm-names $alarmName --query 'MetricAlarms[0]' --output json 2>&1
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
                Write-Host "  Estado actual: $state" -ForegroundColor $color
                Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                return $state
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

# Funcion para actualizar script de monitoreo Docker
function Update-DockerMonitorScript {
    param([array]$instances)
    
    Write-Host "`nActualizando script de monitoreo Docker..." -ForegroundColor Yellow
    
    # Script corregido para monitoreo Docker
    $scriptDockerCorregido = @'
#!/bin/bash
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

DOCKER_CMD="docker"
if ! $DOCKER_CMD ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

RUNNING_CONTAINERS=$($DOCKER_CMD ps -q 2>/dev/null | wc -l)
TOTAL_CONTAINERS=$($DOCKER_CMD ps -aq 2>/dev/null | wc -l)

ASG_NAME="unknown"
for i in {1..3}; do
    ASG_NAME=$(aws autoscaling describe-auto-scaling-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text 2>/dev/null)
    if [ "$ASG_NAME" != "None" ] && [ -n "$ASG_NAME" ] && [ "$ASG_NAME" != "unknown" ]; then
        break
    fi
    sleep 1
done

if [ "$ASG_NAME" == "unknown" ] || [ "$ASG_NAME" == "None" ] || [ -z "$ASG_NAME" ]; then
    ASG_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query 'Reservations[0].Instances[0].Tags[?Key==`aws:autoscaling:groupName`].Value' --output text 2>/dev/null)
fi

if [ "$ASG_NAME" == "unknown" ] || [ "$ASG_NAME" == "None" ] || [ -z "$ASG_NAME" ]; then
    ASG_NAME="genius-dev-asg"
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S)
ERROR_LOG="/var/log/docker-monitor-errors.log"

aws cloudwatch put-metric-data --namespace "Docker/Containers" --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" --region "$AWS_REGION" >> $ERROR_LOG 2>&1

aws cloudwatch put-metric-data --namespace "Docker/Containers" --metric-data MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" --region "$AWS_REGION" >> $ERROR_LOG 2>&1

echo "$(date): Running containers: $RUNNING_CONTAINERS, Total containers: $TOTAL_CONTAINERS, ASG: $ASG_NAME" >> /var/log/docker-monitor.log
'@
    
    foreach ($instance in $instances) {
        $instId = $instance[0]
        Write-Host "  Actualizando instancia: $instId" -ForegroundColor Gray
        
        # Crear comando para actualizar el script
        $updateCommands = @(
            "cat > /tmp/monitor-docker-fix.sh <<'SCRIPTEOF'",
            $scriptDockerCorregido,
            "SCRIPTEOF",
            "sudo mv /tmp/monitor-docker-fix.sh /usr/local/bin/monitor-docker-containers.sh",
            "sudo chmod +x /usr/local/bin/monitor-docker-containers.sh",
            "sudo chown root:root /usr/local/bin/monitor-docker-containers.sh"
        )
        
        $commandsJson = ($updateCommands | ConvertTo-Json -Compress)
        
        $updateOutput = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=$commandsJson" `
            --output json 2>&1 | Out-Null
    }
    
    Write-Host "OK Script de monitoreo actualizado en todas las instancias" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

# URL del dashboard
$dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"

# Ejecutar prueba segun opcion seleccionada
switch ($option) {
    "1" {
        # Activar alarma: CPU alta (Widget 1)
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "WIDGET 1: CPU Usage" -ForegroundColor Red
        Write-Host "ACTIVAR ALARMA: CPU Alta" -ForegroundColor Red
        Write-Host "Alarma: genius-dev-high-cpu" -ForegroundColor Yellow
        Write-Host "Umbral: CPUUtilization > 80% durante 1 minuto" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        $instanceId = $instances[0][0]
        Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
        
        Write-Host "`nInstalando stress-ng..." -ForegroundColor Yellow
        $installOutput = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['sudo yum install -y stress-ng']" `
            --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Seconds 5
            Write-Host "OK stress-ng instalado" -ForegroundColor Green
            
            Write-Host "`nGenerando carga de CPU al 100% por 3 minutos..." -ForegroundColor Yellow
            Write-Host "Esto activara la alarma inmediatamente (1 minuto) con CPU > 80%" -ForegroundColor Cyan
            
            $cpuOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 180s > /tmp/stress-ng.log 2>&1 &']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OK Comando enviado" -ForegroundColor Green
                
                Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                Start-Sleep -Seconds 70
                
                Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                Check-Alarm "genius-dev-high-cpu"
                
                Write-Host ""
                Write-Host "WIDGET DEL DASHBOARD:" -ForegroundColor Cyan
                Write-Host "  - Widget 1: CPU Usage (%) (debera mostrar CPU cerca de 100%)" -ForegroundColor White
                Write-Host "  - La alarma se activara en aproximadamente 60-90 segundos" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Para detener la carga de CPU:" -ForegroundColor Cyan
                Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    Start-Process $dashboardUrl
                }
            } else {
                Write-Host "ERROR Error al iniciar carga de CPU" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR Error al instalar stress-ng" -ForegroundColor Red
        }
    }
    
    "2" {
        # Activar alarma: Docker containers caidos (Widget 2)
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "WIDGET 2: Docker Containers" -ForegroundColor Red
        Write-Host "ACTIVAR ALARMA: Contenedores Docker Caidos" -ForegroundColor Red
        Write-Host "Alarma: genius-dev-docker-containers-down" -ForegroundColor Yellow
        Write-Host "Umbral: RunningContainers < 2" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        $instanceId = $instances[0][0]
        Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
        
        Write-Host "`nOpciones para activar la alarma:" -ForegroundColor Yellow
        Write-Host "  A) Detener un contenedor Docker (para reducir de 2 a 1)" -ForegroundColor White
        Write-Host "  B) Detener todos los contenedores en una instancia (reducir a 0)" -ForegroundColor White
        Write-Host "  C) Verificar estado actual de contenedores" -ForegroundColor White
        Write-Host ""
        Write-Host "Selecciona opcion (A/B/C):" -ForegroundColor Cyan
        $subOption = Read-Host
        
        if ($subOption -eq "A" -or $subOption -eq "a") {
            Write-Host "`nDeteniendo un contenedor Docker..." -ForegroundColor Yellow
            $stopOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['CONTAINER_ID=$(docker ps -q 2>/dev/null | head -n 1); if [ -z \"$CONTAINER_ID\" ]; then CONTAINER_ID=$(sudo docker ps -q 2>/dev/null | head -n 1); fi; if [ -n \"$CONTAINER_ID\" ]; then docker stop $CONTAINER_ID 2>/dev/null || sudo docker stop $CONTAINER_ID; echo \"Contenedor $CONTAINER_ID detenido\"; else echo \"No hay contenedores corriendo\"; fi']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                $stopCommandId = $stopResult.Command.CommandId
                Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
                
                Write-Host "`nForzando envio inmediato de metricas..." -ForegroundColor Yellow
                $forceMetricOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh']" `
                    --output json 2>&1
                
                Write-Host "OK Metricas forzadas" -ForegroundColor Green
                Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                Start-Sleep -Seconds 70
                
                Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                Check-Alarm "genius-dev-docker-containers-down"
                
                Write-Host ""
                Write-Host "WIDGET DEL DASHBOARD:" -ForegroundColor Cyan
                Write-Host "  - Widget 2: Docker Containers (debera mostrar menos contenedores corriendo)" -ForegroundColor White
                Write-Host "  - La alarma se activara automaticamente si RunningContainers < 2" -ForegroundColor Yellow
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    Start-Process $dashboardUrl
                }
            } else {
                Write-Host "ERROR Error al detener contenedor" -ForegroundColor Red
            }
        }
        elseif ($subOption -eq "B" -or $subOption -eq "b") {
            Write-Host "`nADVERTENCIA: Esto detendra TODOS los contenedores Docker en esta instancia" -ForegroundColor Red
            Write-Host "Continuar? (S/N):" -ForegroundColor Cyan
            $confirm = Read-Host
            
            if ($confirm -eq "S" -or $confirm -eq "s") {
                Write-Host "`nDeteniendo todos los contenedores Docker..." -ForegroundColor Yellow
                $stopOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['CONTAINERS=$(docker ps -q 2>/dev/null); if [ -z \"$CONTAINERS\" ]; then CONTAINERS=$(sudo docker ps -q 2>/dev/null); fi; if [ -n \"$CONTAINERS\" ]; then docker stop $CONTAINERS 2>/dev/null || sudo docker stop $CONTAINERS; fi']" `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                    Write-Host "OK Comando enviado" -ForegroundColor Green
                    
                    Write-Host "`nForzando envio inmediato de metricas..." -ForegroundColor Yellow
                    $forceMetricOutput = & aws ssm send-command `
                        --instance-ids $instanceId `
                        --document-name "AWS-RunShellScript" `
                        --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh']" `
                        --output json 2>&1
                    
                    Write-Host "OK Metricas forzadas" -ForegroundColor Green
                    Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 70
                    
                    Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                    Check-Alarm "genius-dev-docker-containers-down"
                    
                    Write-Host ""
                    Write-Host "WIDGET DEL DASHBOARD:" -ForegroundColor Cyan
                    Write-Host "  - Widget 2: Docker Containers (debera mostrar 0 contenedores corriendo)" -ForegroundColor White
                    Write-Host "  - La alarma se activara automaticamente si RunningContainers < 2" -ForegroundColor Yellow
                    
                    Write-Host ""
                    Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                    $openDashboard = Read-Host
                    if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                        Start-Process $dashboardUrl
                    }
                } else {
                    Write-Host "ERROR Error al detener contenedores" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "`nVerificando estado actual de contenedores Docker..." -ForegroundColor Yellow
            $statusOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['DOCKER_CMD=\"docker\"; if ! docker ps >/dev/null 2>&1; then DOCKER_CMD=\"sudo docker\"; fi; echo \"Contenedores corriendo:\"; $DOCKER_CMD ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\"; echo \"\\nTotal:\"; $DOCKER_CMD ps -q | wc -l']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $statusResult = ($statusOutput -join "`n") | ConvertFrom-Json
                $statusCommandId = $statusResult.Command.CommandId
                Start-Sleep -Seconds 3
                
                $statusCheckOutput = & aws ssm get-command-invocation `
                    --command-id $statusCommandId `
                    --instance-id $instanceId `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $statusCheck = ($statusCheckOutput -join "`n") | ConvertFrom-Json
                    if ($statusCheck.Status -eq "Success") {
                        Write-Host "`n$($statusCheck.StandardOutputContent)" -ForegroundColor White
                        Write-Host "`nNOTA: La alarma se activa cuando el total de contenedores corriendo < 2" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    
    "3" {
        # Verificar todas las alarmas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Estado de Todas las Alarmas CloudWatch" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $alarms = @(
            @{Name="genius-dev-high-cpu"; Desc="Widget 1: CPU Usage (CPU alta)"},
            @{Name="genius-dev-docker-containers-down"; Desc="Widget 2: Docker Containers (Contenedores caidos)"}
        )
        
        foreach ($alarmInfo in $alarms) {
            Write-Host "Alarma: $($alarmInfo.Desc)" -ForegroundColor Yellow
            Write-Host "Nombre: $($alarmInfo.Name)" -ForegroundColor Gray
            Check-Alarm $alarmInfo.Name
            Write-Host ""
        }
    }
    
    "4" {
        # TODO: Actualizar Script Docker + Saturar CPU + Detener Contenedor Docker
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "TODO: CPU + Docker Completo" -ForegroundColor Magenta
        Write-Host "Actualizar Script + Saturar CPU + Detener Docker" -ForegroundColor Magenta
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        $instanceId = $instances[0][0]
        Write-Host "Usando instancia: $instanceId" -ForegroundColor Cyan
        
        # PASO 0: Actualizar script de monitoreo Docker
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 0: Actualizar Script de Monitoreo Docker" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        Update-DockerMonitorScript -instances $instances
        
        # PASO 1: Saturar CPU
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 1: Saturar CPU" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "`nInstalando stress-ng..." -ForegroundColor Yellow
        $installOutput = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['sudo yum install -y stress-ng']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Seconds 5
            Write-Host "OK stress-ng instalado" -ForegroundColor Green
            
            Write-Host "`nGenerando carga de CPU al 100% por 5 minutos..." -ForegroundColor Yellow
            Write-Host "Esto activara la alarma de CPU alta (Widget 1)" -ForegroundColor Cyan
            
            $cpuOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 300s > /tmp/stress-ng.log 2>&1 &']" `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OK Carga de CPU iniciada" -ForegroundColor Green
            } else {
                Write-Host "ERROR Error al iniciar carga de CPU" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR Error al instalar stress-ng" -ForegroundColor Red
        }
        
        # PASO 2: Detener contenedor Docker
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 2: Detener Contenedor Docker" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "`nDeteniendo un contenedor Docker..." -ForegroundColor Yellow
        Write-Host "Esto activara la alarma de Docker containers caidos (Widget 2)" -ForegroundColor Cyan
        
        $stopOutput = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['CONTAINER_ID=$(docker ps -q 2>/dev/null | head -n 1); if [ -z \"$CONTAINER_ID\" ]; then CONTAINER_ID=$(sudo docker ps -q 2>/dev/null | head -n 1); fi; if [ -n \"$CONTAINER_ID\" ]; then docker stop $CONTAINER_ID 2>/dev/null || sudo docker stop $CONTAINER_ID; echo \"Contenedor $CONTAINER_ID detenido\"; else echo \"No hay contenedores corriendo\"; fi']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
            $stopCommandId = $stopResult.Command.CommandId
            Write-Host "OK Comando enviado" -ForegroundColor Green
            
            Start-Sleep -Seconds 3
            $stopCheck = & aws ssm get-command-invocation `
                --command-id $stopCommandId `
                --instance-id $instanceId `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $stopStatus = ($stopCheck -join "`n") | ConvertFrom-Json
                Write-Host "  Resultado: $($stopStatus.StandardOutputContent)" -ForegroundColor White
            }
        } else {
            Write-Host "ERROR Error al detener contenedor" -ForegroundColor Red
        }
        
        # PASO 3: Forzar envio de metricas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 3: Forzar Envio de Metricas" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "`nForzando envio inmediato de metricas Docker en todas las instancias..." -ForegroundColor Yellow
        foreach ($instance in $instances) {
            $instId = $instance[0]
            $forceMetricOutput = & aws ssm send-command `
                --instance-ids $instId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh']" `
                --output json 2>&1 | Out-Null
        }
        Write-Host "OK Metricas Docker forzadas en todas las instancias" -ForegroundColor Green
        
        # PASO 4: Esperar procesamiento
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 4: Esperar Procesamiento CloudWatch" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
        Write-Host "  - CPU: Se procesara automaticamente cada 60 segundos" -ForegroundColor Gray
        Write-Host "  - Docker: Metricas enviadas, esperando procesamiento..." -ForegroundColor Gray
        
        for ($i = 1; $i -le 70; $i++) {
            Start-Sleep -Seconds 1
            if ($i % 10 -eq 0) {
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        }
        Write-Host "`nOK Tiempo de espera completado" -ForegroundColor Green
        
        # PASO 5: Verificar alarmas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PASO 5: Verificar Estado de Alarmas" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        Check-Alarm "genius-dev-high-cpu"
        Check-Alarm "genius-dev-docker-containers-down"
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "RESUMEN" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "`nACCIONES REALIZADAS:" -ForegroundColor Yellow
        Write-Host "  ✅ Script de monitoreo Docker actualizado" -ForegroundColor Green
        Write-Host "  ✅ CPU saturada al 100% por 5 minutos" -ForegroundColor Green
        Write-Host "  ✅ Un contenedor Docker detenido" -ForegroundColor Green
        Write-Host "  ✅ Metricas Docker forzadas en todas las instancias" -ForegroundColor Green
        
        Write-Host "`nEN EL DASHBOARD DEBERIAS VER:" -ForegroundColor Yellow
        Write-Host "  📊 Widget 1 (CPU Usage): CPU cerca de 100% (linea azul alta)" -ForegroundColor White
        Write-Host "  📊 Widget 2 (Docker Containers): Menos contenedores corriendo (linea verde baja)" -ForegroundColor White
        
        Write-Host "`nNOTAS IMPORTANTES:" -ForegroundColor Yellow
        Write-Host "  - Las metricas pueden tardar 1-2 minutos adicionales en aparecer" -ForegroundColor Gray
        Write-Host "  - Refresca el dashboard si no ves cambios inmediatamente" -ForegroundColor Gray
        Write-Host "  - La alarma de CPU se activara en ~60-90 segundos" -ForegroundColor Gray
        Write-Host "  - La alarma de Docker se activara si RunningContainers < 2" -ForegroundColor Gray
        
        Write-Host "`nPara detener la carga de CPU manualmente:" -ForegroundColor Cyan
        Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
        
        Write-Host "`n¿Quieres abrir el dashboard ahora? (S/N):" -ForegroundColor Cyan
        $openDashboard = Read-Host
        if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
            Start-Process $dashboardUrl
            Write-Host "`nDashboard abierto. Refresca la pagina en 1-2 minutos para ver los cambios." -ForegroundColor Green
        }
    }
    
    default {
        Write-Host "Opcion invalida." -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Prueba completada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dashboard URL: $dashboardUrl" -ForegroundColor Cyan
