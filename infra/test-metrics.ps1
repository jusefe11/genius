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
Write-Host "VERIFICACION:" -ForegroundColor White
Write-Host "  3. Verificar estado de todas las alarmas" -ForegroundColor Green
Write-Host ""
Write-Host "Selecciona una opcion (1-3):" -ForegroundColor Cyan
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
                --parameters "commands=['sudo docker stop `$(sudo docker ps -q | head -n 1)']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                $stopCommandId = $stopResult.Command.CommandId
                Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
                
                Write-Host "`nForzando envio inmediato de metricas..." -ForegroundColor Yellow
                # Ejecutar el script de monitoreo manualmente para enviar metricas inmediatamente
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
                    --parameters "commands=['sudo docker stop $(sudo docker ps -q)']" `
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
                --parameters "commands=['echo \"Contenedores corriendo:\"; sudo docker ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\"; echo \"\\nTotal:\"; sudo docker ps -q | wc -l']" `
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
    
    default {
        Write-Host "Opcion invalida." -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Prueba completada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dashboard URL: $dashboardUrl" -ForegroundColor Cyan
