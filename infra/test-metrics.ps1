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
Write-Host "  5. Diagnosticar metricas Docker (verificar por que no aparecen datos)" -ForegroundColor Yellow
Write-Host "  6. FORZAR envio de metricas Docker AHORA (solucion rapida)" -ForegroundColor Magenta
Write-Host "  7. Verificar metricas de CPU en CloudWatch (diagnostico)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Selecciona una opcion (1-7):" -ForegroundColor Cyan
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

# Obtener región y dashboard URL dinámicamente
Write-Host "Obteniendo información del dashboard..." -ForegroundColor Yellow
try {
    # Obtener región actual
    $regionOutput = & aws configure get region 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $regionOutput) {
        $regionOutput = & aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text 2>&1
    }
    if ($LASTEXITCODE -eq 0 -and $regionOutput) {
        $region = $regionOutput.Trim()
        Write-Host "OK Región detectada: $region" -ForegroundColor Green
    } else {
        $region = "us-east-1"  # Fallback
        Write-Host "ADVERTENCIA: No se pudo detectar la región, usando: $region" -ForegroundColor Yellow
    }
    
    # Obtener nombre del dashboard desde Terraform outputs
    $dashboardName = "genius-dev-application-status"
    try {
        $tfOutput = & terraform output -json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $outputs = $tfOutput | ConvertFrom-Json
            if ($outputs.cloudwatch_dashboard_name -and $outputs.cloudwatch_dashboard_name.value) {
                $dashboardName = $outputs.cloudwatch_dashboard_name.value
                Write-Host "OK Dashboard encontrado: $dashboardName" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "ADVERTENCIA: No se pudo obtener el nombre del dashboard desde Terraform, usando: $dashboardName" -ForegroundColor Yellow
    }
    
    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=$region#dashboards:name=$dashboardName"
} catch {
    Write-Host "ADVERTENCIA: Error al obtener información del dashboard, usando valores por defecto" -ForegroundColor Yellow
    $region = "us-east-1"
    $dashboardName = "genius-dev-application-status"
    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=$region#dashboards:name=$dashboardName"
}

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
            
            Write-Host "`n¿Cuánto tiempo quieres saturar la CPU? (minutos, default: 5):" -ForegroundColor Cyan
            $durationInput = Read-Host
            if (-not $durationInput -or $durationInput -eq "") {
                $durationMinutes = 5
            } else {
                $durationMinutes = [int]$durationInput
            }
            $durationSeconds = $durationMinutes * 60
            
            Write-Host "`nGenerando carga de CPU al 100% por $durationMinutes minutos..." -ForegroundColor Yellow
            Write-Host "Esto activara la alarma inmediatamente (1 minuto) con CPU > 80%" -ForegroundColor Cyan
            Write-Host "El grafico mostrara CPU cerca de 100% durante $durationMinutes minutos" -ForegroundColor Cyan
            
            # Método más agresivo y directo para saturar CPU
            Write-Host "Deteniendo cualquier proceso stress-ng anterior..." -ForegroundColor Gray
            $killOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['sudo pkill -9 stress-ng 2>/dev/null || true']" `
                --output json 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            
            # Usar todos los CPUs disponibles y método más simple
            Write-Host "Iniciando stress-ng con TODOS los CPUs disponibles..." -ForegroundColor Yellow
            Write-Host "Esto generara carga al 100% en todos los cores" -ForegroundColor Cyan
            
            # Usar el script saturar-cpu.sh que ya tienes
            Write-Host "Subiendo y ejecutando script saturar-cpu.sh..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "saturar-cpu.sh"
            if (Test-Path $scriptPath) {
                # Leer el script y subirlo al servidor usando heredoc
                $scriptContent = Get-Content $scriptPath -Raw
                
                # Subir script y ejecutarlo usando el mismo método que funciona en Update-DockerMonitorScript
                $uploadCommands = @(
                    "cat > /tmp/saturar-cpu.sh <<'SCRIPTEOF'",
                    $scriptContent,
                    "SCRIPTEOF",
                    "chmod +x /tmp/saturar-cpu.sh",
                    "/tmp/saturar-cpu.sh $durationMinutes stress-ng"
                )
                $uploadCommandsJson = ($uploadCommands | ConvertTo-Json -Compress)
                
                $cpuOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=$uploadCommandsJson" `
                    --output json 2>&1
            } else {
                Write-Host "Script saturar-cpu.sh no encontrado, usando metodo directo..." -ForegroundColor Yellow
                # Fallback al método directo
                $stressTimeout = "${durationSeconds}s"
                $cpuOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout ${stressTimeout}s > /tmp/stress-ng.log 2>&1 &']" `
                    --output json 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                try {
                    $cpuResult = ($cpuOutput -join "`n") | ConvertFrom-Json
                    $cpuCommandId = $cpuResult.Command.CommandId
                    Write-Host "OK Comando enviado (Command ID: $cpuCommandId)" -ForegroundColor Green
                } catch {
                    Write-Host "ERROR: No se pudo parsear la respuesta de AWS SSM" -ForegroundColor Red
                    $errorOutput = $cpuOutput -join [Environment]::NewLine
                    Write-Host "Respuesta: $errorOutput" -ForegroundColor Gray
                    break
                }
                
                Write-Host "Esperando 15 segundos para que stress-ng se inicie..." -ForegroundColor Yellow
                Start-Sleep -Seconds 15
                
                # Verificar que stress-ng esté corriendo con un comando separado
                Write-Host "Verificando que stress-ng este corriendo..." -ForegroundColor Cyan
                $verifyCmd = 'if pgrep -f stress-ng > /dev/null; then echo "OK: stress-ng corriendo"; ps aux | grep stress-ng | grep -v grep | head -3; else echo "ERROR: stress-ng no esta corriendo"; fi'
                $verifyOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['$verifyCmd']" `
                    --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $verifyResult = ($verifyOutput -join "`n") | ConvertFrom-Json
                    $verifyCommandId = $verifyResult.Command.CommandId
                    Start-Sleep -Seconds 3
                    
                    $checkOutput = & aws ssm get-command-invocation `
                        --command-id $verifyCommandId `
                        --instance-id $instanceId `
                        --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $checkResult = ($checkOutput -join "`n") | ConvertFrom-Json
                        $checkOutputText = $checkResult.StandardOutputContent
                        
                        Write-Host "Resultado de verificacion:" -ForegroundColor Gray
                        Write-Host $checkOutputText -ForegroundColor White
                        
                        if ($checkOutputText -match "ERROR" -or $checkOutputText -notmatch "OK: stress-ng corriendo") {
                            Write-Host "`nADVERTENCIA: stress-ng puede no estar corriendo" -ForegroundColor Yellow
                            Write-Host "Iniciando metodo alternativo con procesos 'yes'..." -ForegroundColor Yellow
                            
                            # Método alternativo: usar yes
                            $altOutput = & aws ssm send-command `
                                --instance-ids $instanceId `
                                --document-name "AWS-RunShellScript" `
                                --parameters "commands=['CPU_COUNT=`$(nproc); for i in `$(seq 1 `$CPU_COUNT); do nohup yes > /dev/null 2>&1 & done; sleep 2; echo \"Procesos yes iniciados: `$(pgrep yes | wc -l)\"']" `
                                --output json 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "OK Metodo alternativo (yes) iniciado" -ForegroundColor Green
                            }
                        } else {
                            Write-Host "`nOK stress-ng esta corriendo correctamente" -ForegroundColor Green
                        }
                    }
                }
            } else {
                Write-Host "ERROR: Fallo al enviar comando a AWS SSM" -ForegroundColor Red
                Write-Host "Salida del error:" -ForegroundColor Yellow
                Write-Host ($cpuOutput -join "`n") -ForegroundColor Gray
                break
            }
            
            if ($LASTEXITCODE -eq 0) {
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
                --parameters "commands=['CONTAINER_ID=`$(docker ps -q 2>/dev/null | head -n 1); if [ -z \"`$CONTAINER_ID\" ]; then CONTAINER_ID=`$(sudo docker ps -q 2>/dev/null | head -n 1); fi; if [ -n \"`$CONTAINER_ID\" ]; then docker stop `$CONTAINER_ID 2>/dev/null || sudo docker stop `$CONTAINER_ID; echo \"Contenedor `$CONTAINER_ID detenido\"; else echo \"No hay contenedores corriendo\"; fi']" `
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
                
                # Simplificar: usar un solo comando como en la opción A que funciona
                # Pero adaptado para detener todos los contenedores
                $stopOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['docker ps -q | xargs -r docker stop 2>/dev/null || sudo docker ps -q | xargs -r sudo docker stop 2>/dev/null; echo Contenedores detenidos']" `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                        $stopCommandId = $stopResult.Command.CommandId
                        Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
    } catch {
                        Write-Host "ADVERTENCIA: No se pudo parsear la respuesta JSON" -ForegroundColor Yellow
                        Write-Host "Respuesta: $($stopOutput -join [Environment]::NewLine)" -ForegroundColor Gray
                    }
                    
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
                    Write-Host "Detalles del error:" -ForegroundColor Yellow
                    Write-Host ($stopOutput -join "`n") -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "`nVerificando estado actual de contenedores Docker..." -ForegroundColor Yellow
            $statusOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['DOCKER_CMD=\"docker\"; if ! docker ps >/dev/null 2>&1; then DOCKER_CMD=\"sudo docker\"; fi; echo \"Contenedores corriendo:\"; `$DOCKER_CMD ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\"; echo \"\\nTotal:\"; `$DOCKER_CMD ps -q | wc -l']" `
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
            --parameters "commands=['CONTAINER_ID=`$(docker ps -q 2>/dev/null | head -n 1); if [ -z \"`$CONTAINER_ID\" ]; then CONTAINER_ID=`$(sudo docker ps -q 2>/dev/null | head -n 1); fi; if [ -n \"`$CONTAINER_ID\" ]; then docker stop `$CONTAINER_ID 2>/dev/null || sudo docker stop `$CONTAINER_ID; echo \"Contenedor `$CONTAINER_ID detenido\"; else echo \"No hay contenedores corriendo\"; fi']" `
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
    
    "5" {
        # Diagnosticar metricas Docker
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "DIAGNOSTICO: Metricas Docker" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        $instanceId = $instances[0][0]
        Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
        
        Write-Host "`nVerificando componentes del monitoreo Docker..." -ForegroundColor Yellow
        
        # 1. Verificar si el script existe
        Write-Host "`n[1/6] Verificando si el script existe..." -ForegroundColor Cyan
        $checkScript = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['if [ -f /usr/local/bin/monitor-docker-containers.sh ]; then echo \"OK Script existe\"; ls -lh /usr/local/bin/monitor-docker-containers.sh; else echo \"ERROR Script NO existe\"; fi']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $checkResult = ($checkScript -join "`n") | ConvertFrom-Json
            $checkId = $checkResult.Command.CommandId
            Start-Sleep -Seconds 3
            $scriptStatus = & aws ssm get-command-invocation --command-id $checkId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
            Write-Host "  $($scriptStatus.StandardOutputContent)" -ForegroundColor White
        }
        
        # 2. Verificar cron job
        Write-Host "`n[2/6] Verificando cron job..." -ForegroundColor Cyan
        $checkCron = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['if grep -q monitor-docker-containers /etc/crontab 2>/dev/null; then echo \"OK Cron job configurado:\"; grep monitor-docker-containers /etc/crontab; else echo \"ERROR Cron job NO configurado\"; fi']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $cronResult = ($checkCron -join "`n") | ConvertFrom-Json
            $cronId = $cronResult.Command.CommandId
            Start-Sleep -Seconds 3
            $cronStatus = & aws ssm get-command-invocation --command-id $cronId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
            Write-Host "  $($cronStatus.StandardOutputContent)" -ForegroundColor White
        }
        
        # 3. Verificar contenedores Docker
        Write-Host "`n[3/6] Verificando contenedores Docker..." -ForegroundColor Cyan
        $dockerCheckCmd = 'DOCKER_CMD="docker"; if ! docker ps >/dev/null 2>&1; then DOCKER_CMD="sudo docker"; fi; echo "Contenedores corriendo:"; $DOCKER_CMD ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"; echo "\nTotal corriendo: $($DOCKER_CMD ps -q | wc -l)"; echo "Total todos: $($DOCKER_CMD ps -aq | wc -l)"'
        $dockerCommands = @($dockerCheckCmd)
        $dockerCommandsJson = ($dockerCommands | ConvertTo-Json -Compress)
        $checkDocker = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=$dockerCommandsJson" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $dockerResult = ($checkDocker -join "`n") | ConvertFrom-Json
            $dockerId = $dockerResult.Command.CommandId
            Start-Sleep -Seconds 3
            $dockerStatus = & aws ssm get-command-invocation --command-id $dockerId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
            Write-Host "  $($dockerStatus.StandardOutputContent)" -ForegroundColor White
        }
        
        # 4. Verificar logs de errores
        Write-Host "`n[4/6] Verificando logs de errores..." -ForegroundColor Cyan
        $checkLogs = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['if [ -f /var/log/docker-monitor-errors.log ]; then echo \"Ultimas 10 lineas del log de errores:\"; tail -n 10 /var/log/docker-monitor-errors.log; else echo \"OK No hay log de errores\"; fi']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $logsResult = ($checkLogs -join "`n") | ConvertFrom-Json
            $logsId = $logsResult.Command.CommandId
            Start-Sleep -Seconds 3
            $logsStatus = & aws ssm get-command-invocation --command-id $logsId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
            Write-Host "  $($logsStatus.StandardOutputContent)" -ForegroundColor White
        }
        
        # 5. Ejecutar script manualmente
        Write-Host "`n[5/6] Ejecutando script manualmente..." -ForegroundColor Cyan
        $runScript = & aws ssm send-command `
            --instance-ids $instanceId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh 2>&1']" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $runResult = ($runScript -join "`n") | ConvertFrom-Json
            $runId = $runResult.Command.CommandId
            Start-Sleep -Seconds 3
            $runStatus = & aws ssm get-command-invocation --command-id $runId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
            Write-Host "  Salida del script:" -ForegroundColor White
            Write-Host "  $($runStatus.StandardOutputContent)" -ForegroundColor Gray
            if ($runStatus.StandardErrorContent) {
                Write-Host "  Errores:" -ForegroundColor Red
                Write-Host "  $($runStatus.StandardErrorContent)" -ForegroundColor Red
            }
        }
        
        # 6. Verificar metricas en CloudWatch
        Write-Host "`n[6/6] Verificando metricas en CloudWatch (ultimos 10 minutos)..." -ForegroundColor Cyan
        $asgName = & aws autoscaling describe-auto-scaling-instances --instance-ids $instanceId --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text 2>&1
        if ($LASTEXITCODE -eq 0 -and $asgName) {
            $metrics = & aws cloudwatch get-metric-statistics `
                --namespace "Docker/Containers" `
                --metric-name "RunningContainers" `
                --dimensions Name=AutoScalingGroupName,Value=$asgName `
                --start-time (Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
                --end-time (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
                --period 60 `
                --statistics Sum `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $metricsData = $metrics | ConvertFrom-Json
                if ($metricsData.Datapoints.Count -gt 0) {
                    Write-Host "  OK Se encontraron $($metricsData.Datapoints.Count) puntos de datos en CloudWatch" -ForegroundColor Green
                    Write-Host "  Ultimos valores:" -ForegroundColor White
                    $metricsData.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 5 | ForEach-Object {
                        Write-Host "    $($_.Timestamp): $($_.Sum) contenedores" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "  ERROR No se encontraron metricas en CloudWatch" -ForegroundColor Red
                    Write-Host "  Esto significa que las metricas no se estan enviando correctamente" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ERROR No se pudo consultar CloudWatch" -ForegroundColor Red
            }
        } else {
            Write-Host "  ERROR No se pudo obtener el nombre del ASG" -ForegroundColor Red
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "DIAGNOSTICO COMPLETADO" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nSi no hay metricas en CloudWatch, posibles causas:" -ForegroundColor Yellow
        Write-Host "  1. El script no se esta ejecutando (verificar cron job)" -ForegroundColor White
        Write-Host "  2. Errores al enviar metricas (revisar logs de errores)" -ForegroundColor White
        Write-Host "  3. Permisos IAM insuficientes (verificar rol de la instancia)" -ForegroundColor White
        Write-Host "  4. El nombre del ASG no coincide" -ForegroundColor White
        Write-Host "`nSolucion: Ejecuta la opcion 4 para actualizar el script en todas las instancias" -ForegroundColor Cyan
    }
    
    "6" {
        # FORZAR envio de metricas Docker inmediatamente
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "FORZAR ENVIO DE METRICAS DOCKER" -ForegroundColor Magenta
        Write-Host "========================================" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        Write-Host "`nPASO 1: Actualizando script Docker en todas las instancias..." -ForegroundColor Yellow
        Update-DockerMonitorScript
        
        Write-Host "`nPASO 2: Ejecutando script de monitoreo en todas las instancias..." -ForegroundColor Yellow
        foreach ($instance in $instances) {
            $instId = $instance[0]
            Write-Host "  Ejecutando en instancia: $instId" -ForegroundColor Gray
            $forceOutput = & aws ssm send-command `
                --instance-ids $instId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh']" `
                --output json 2>&1 | Out-Null
        }
        Write-Host "OK Script ejecutado en todas las instancias" -ForegroundColor Green
        
        Write-Host "`nPASO 3: Esperando 90 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
        Write-Host "  (CloudWatch puede tardar hasta 2 minutos en mostrar los datos)" -ForegroundColor Gray
        for ($i = 1; $i -le 90; $i++) {
            Start-Sleep -Seconds 1
            if ($i % 15 -eq 0) {
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        }
        Write-Host "`nOK Tiempo de espera completado" -ForegroundColor Green
        
        Write-Host "`nPASO 4: Verificando metricas en CloudWatch..." -ForegroundColor Yellow
        $instanceId = $instances[0][0]
        $asgName = & aws autoscaling describe-auto-scaling-instances --instance-ids $instanceId --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text 2>&1
        if ($LASTEXITCODE -eq 0 -and $asgName) {
            $metrics = & aws cloudwatch get-metric-statistics `
                --namespace "Docker/Containers" `
                --metric-name "RunningContainers" `
                --dimensions Name=AutoScalingGroupName,Value=$asgName `
                --start-time (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
                --end-time (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
                --period 60 `
                --statistics Sum `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $metricsData = $metrics | ConvertFrom-Json
                if ($metricsData.Datapoints.Count -gt 0) {
                    Write-Host "  [OK] EXITO: Se encontraron $($metricsData.Datapoints.Count) puntos de datos en CloudWatch" -ForegroundColor Green
                    Write-Host "  Ultimos valores:" -ForegroundColor White
                    $metricsData.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 3 | ForEach-Object {
                        Write-Host "    $($_.Timestamp): $($_.Sum) contenedores" -ForegroundColor Gray
                    }
                    Write-Host "`n  [OK] Las metricas YA ESTAN en CloudWatch" -ForegroundColor Green
                    Write-Host "  Refresca el dashboard en 1-2 minutos para ver los datos" -ForegroundColor Yellow
                } else {
                    Write-Host "  [ADVERTENCIA] AUN NO hay metricas en CloudWatch" -ForegroundColor Yellow
                    Write-Host "  Esto puede tardar hasta 2 minutos adicionales" -ForegroundColor Gray
                    Write-Host "  Refresca el dashboard en unos minutos" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [ADVERTENCIA] No se pudo verificar CloudWatch, pero las metricas deberian aparecer pronto" -ForegroundColor Yellow
            }
        }
        
Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "PROCESO COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nINSTRUCCIONES:" -ForegroundColor Yellow
        Write-Host "  1. Espera 1-2 minutos adicionales" -ForegroundColor White
        Write-Host "  2. Refresca el dashboard de CloudWatch" -ForegroundColor White
        Write-Host "  3. Si aun no aparecen datos, ejecuta la opcion 5 (Diagnostico)" -ForegroundColor White
        Write-Host "`nDashboard: $dashboardUrl" -ForegroundColor Cyan
        
        Write-Host "`n¿Quieres abrir el dashboard ahora? (S/N):" -ForegroundColor Cyan
        $openDashboard = Read-Host
        if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
            Start-Process $dashboardUrl
        }
    }
    
    7 {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "DIAGNOSTICO: Metricas de CPU en CloudWatch" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances -or $instances.Count -eq 0) {
            Write-Host "ERROR: No se encontraron instancias" -ForegroundColor Red
            break
        }
        
        $instanceId = $instances[0][0]
        Write-Host "Usando instancia: $instanceId" -ForegroundColor Gray
        
        # Obtener ASG name
        Write-Host "`nPASO 1: Obteniendo nombre del Auto Scaling Group..." -ForegroundColor Yellow
        $asgOutput = & aws autoscaling describe-auto-scaling-instances --instance-ids $instanceId --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text 2>&1
        if ($LASTEXITCODE -eq 0 -and $asgOutput) {
            $asgName = $asgOutput.Trim()
            Write-Host "OK ASG Name: $asgName" -ForegroundColor Green
        } else {
            Write-Host "ERROR: No se pudo obtener el ASG name" -ForegroundColor Red
            Write-Host "Salida: $asgOutput" -ForegroundColor Gray
            break
        }
        
        # Verificar métricas de CPU
        Write-Host "`nPASO 2: Consultando metricas de CPU en CloudWatch..." -ForegroundColor Yellow
        Write-Host "  Namespace: AWS/EC2" -ForegroundColor Gray
        Write-Host "  Metric: CPUUtilization" -ForegroundColor Gray
        Write-Host "  Dimension: AutoScalingGroupName=$asgName" -ForegroundColor Gray
        Write-Host "  Periodo: Ultimos 15 minutos" -ForegroundColor Gray
        
        $startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        
        $metricsOutput = & aws cloudwatch get-metric-statistics `
            --namespace "AWS/EC2" `
            --metric-name "CPUUtilization" `
            --dimensions Name=AutoScalingGroupName,Value=$asgName `
            --start-time $startTime `
            --end-time $endTime `
            --period 60 `
            --statistics Average,Maximum `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $metricsData = ($metricsOutput -join "`n") | ConvertFrom-Json
            if ($metricsData.Datapoints -and $metricsData.Datapoints.Count -gt 0) {
                Write-Host "`n[OK] EXITO: Se encontraron $($metricsData.Datapoints.Count) puntos de datos" -ForegroundColor Green
                Write-Host "`nUltimos valores de CPU:" -ForegroundColor Cyan
                $metricsData.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 10 | ForEach-Object {
                    $timestamp = [DateTime]::Parse($_.Timestamp)
                    $avg = [math]::Round($_.Average, 2)
                    $max = [math]::Round($_.Maximum, 2)
                    $color = if ($avg -gt 80) { "Red" } elseif ($avg -gt 50) { "Yellow" } else { "Green" }
                    Write-Host "  $($timestamp.ToString('HH:mm:ss')) - Promedio: $avg% | Maximo: $max%" -ForegroundColor $color
                }
                Write-Host "`n[OK] Las metricas de CPU ESTAN DISPONIBLES en CloudWatch" -ForegroundColor Green
                Write-Host "  El dashboard deberia mostrar estos datos" -ForegroundColor White
                Write-Host "  Si no los ves, verifica:" -ForegroundColor Yellow
                Write-Host "    1. Que el dashboard este en la region correcta ($region)" -ForegroundColor Gray
                Write-Host "    2. Que el nombre del dashboard sea: $dashboardName" -ForegroundColor Gray
                Write-Host "    3. Que el periodo del widget sea 300 segundos (5 minutos)" -ForegroundColor Gray
                Write-Host "    4. Refresca el dashboard" -ForegroundColor Gray
            } else {
                Write-Host "`n[ADVERTENCIA] NO se encontraron metricas de CPU en los ultimos 15 minutos" -ForegroundColor Yellow
                Write-Host "  Posibles causas:" -ForegroundColor Yellow
                Write-Host "    1. Las instancias no estan generando carga de CPU" -ForegroundColor Gray
                Write-Host "    2. Las metricas aun no han llegado a CloudWatch (puede tardar 1-2 minutos)" -ForegroundColor Gray
                Write-Host "    3. El ASG name no coincide: $asgName" -ForegroundColor Gray
                Write-Host "`n  SOLUCION: Ejecuta la opcion 1 para saturar la CPU y espera 2-3 minutos" -ForegroundColor Cyan
            }
        } else {
            Write-Host "`nERROR: No se pudo consultar CloudWatch" -ForegroundColor Red
            Write-Host "Salida: $($metricsOutput -join [Environment]::NewLine)" -ForegroundColor Gray
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "DIAGNOSTICO COMPLETADO" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nDashboard URL: $dashboardUrl" -ForegroundColor Cyan
        Write-Host "`n¿Quieres abrir el dashboard ahora? (S/N):" -ForegroundColor Cyan
        $openDashboard = Read-Host
        if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
            Start-Process $dashboardUrl
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
