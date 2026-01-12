# Script para probar las metricas de CloudWatch
# Dashboard simplificado: Estado de aplicacion, CPU y RAM

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

# Obtener la URL del ALB
Write-Host "Obteniendo URL del ALB..." -ForegroundColor Yellow
try {
    $albOutput = & terraform output -raw alb_dns_name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $albDns = ($albOutput -join "`n").Trim()
    } else {
        $albDns = $null
    }
    if (-not $albDns) {
        Write-Host "Error: No se pudo obtener la URL del ALB" -ForegroundColor Red
        Write-Host "Asegurate de que Terraform este inicializado y que el ALB este desplegado" -ForegroundColor Yellow
        exit 1
    }
    
    $albUrl = "http://$albDns"
    Write-Host "OK URL del ALB: $albUrl" -ForegroundColor Green
} catch {
    Write-Host "Error al obtener la URL del ALB: $_" -ForegroundColor Red
    exit 1
}

# Verificar conectividad
Write-Host "`nVerificando conectividad..." -ForegroundColor Yellow
try {
    $testResponse = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 10
    Write-Host "OK Conectividad OK - Status: $($testResponse.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Advertencia: No se pudo conectar al ALB: $_" -ForegroundColor Yellow
    Write-Host "Continuando de todas formas para generar trafico..." -ForegroundColor Yellow
}

# Menu de opciones de prueba
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Pruebas para Activar Alarmas CloudWatch" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ACTIVAR ALARMAS (Pruebas de Fallo):" -ForegroundColor Red
Write-Host "  1. Activar alarma: Contenedores Docker caidos [docker-containers-down]" -ForegroundColor Red
Write-Host "  2. Activar alarma: Aplicacion caida [no-healthy-hosts]" -ForegroundColor Red
Write-Host "  3. Activar alarma: CPU alta [high-cpu]" -ForegroundColor Red
Write-Host "  4. Activar alarma: RAM alta [high-memory]" -ForegroundColor Red
Write-Host ""
Write-Host "GENERAR TRAFICO (Metricas normales):" -ForegroundColor Yellow
Write-Host "  5. Generar trafico para HealthyHostCount (verificar aplicacion activa)" -ForegroundColor Yellow
Write-Host ""
Write-Host "VERIFICACION:" -ForegroundColor White
Write-Host "  6. Verificar estado de todas las alarmas" -ForegroundColor Green
Write-Host ""
Write-Host "Selecciona una opcion (1-6):" -ForegroundColor Cyan
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

# Ejecutar prueba segun opcion seleccionada
switch ($option) {
    "1" {
        # Activar alarma: Contenedores Docker caidos
        Write-Host "`n========================================" -ForegroundColor Cyan
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
                --parameters "commands=['CONTAINER_ID=$(sudo docker ps -q | head -1); if [ -n \"$CONTAINER_ID\" ]; then sudo docker stop $CONTAINER_ID; echo \"Contenedor $CONTAINER_ID detenido\"; else echo \"No hay contenedores corriendo\"; fi']" `
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
                Write-Host "La alarma se activara automaticamente en 60 segundos" -ForegroundColor Yellow
                Write-Host "La alarma mostrara cuantos contenedores estan arriba en StateReason" -ForegroundColor Cyan
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
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
                    Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                    $openDashboard = Read-Host
                    if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                        $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
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
    
    "2" {
        # Activar alarma: Aplicacion caida
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "ACTIVAR ALARMA: Aplicacion Caida" -ForegroundColor Red
        Write-Host "Alarma: genius-dev-no-healthy-hosts" -ForegroundColor Yellow
        Write-Host "Umbral: HealthyHostCount < 1" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $instances = Get-EC2Instances
        if (-not $instances) { break }
        
        $instanceId = $instances[0][0]
        Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
        
        Write-Host "`nOpciones para activar la alarma:" -ForegroundColor Yellow
        Write-Host "  A) Detener todos los contenedores Docker en una instancia" -ForegroundColor White
        Write-Host "  B) Detener el servicio Docker" -ForegroundColor White
        Write-Host "  C) Detener contenedores en todas las instancias (causa aplicacion caida completa)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Selecciona opcion (A/B/C):" -ForegroundColor Cyan
        $subOption = Read-Host
        
        if ($subOption -eq "A" -or $subOption -eq "a") {
            Write-Host "`nDeteniendo todos los contenedores Docker..." -ForegroundColor Yellow
            $stopOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['sudo docker stop $(sudo docker ps -q)']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                Write-Host "OK Comando enviado" -ForegroundColor Green
                
                Write-Host "`nGenerando trafico para activar las metricas..." -ForegroundColor Yellow
                for ($i = 1; $i -le 20; $i++) {
                    try {
                        Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 3 | Out-Null
                        Write-Host "." -NoNewline -ForegroundColor Green
                    } catch { 
                        Write-Host "x" -NoNewline -ForegroundColor Red
                    }
                    Start-Sleep -Milliseconds 300
                }
                Write-Host "`nOK Trafico generado" -ForegroundColor Green
                
                Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                Start-Sleep -Seconds 70
                
                Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                Check-Alarm "genius-dev-no-healthy-hosts"
                
                Write-Host ""
                Write-Host "La alarma se activara automaticamente si HealthyHostCount < 1" -ForegroundColor Yellow
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
                    Start-Process $dashboardUrl
                }
            }
        }
        elseif ($subOption -eq "B" -or $subOption -eq "b") {
            Write-Host "`nADVERTENCIA: Esto detendra el servicio Docker completamente" -ForegroundColor Red
            Write-Host "Continuar? (S/N):" -ForegroundColor Cyan
            $confirm = Read-Host
            
            if ($confirm -eq "S" -or $confirm -eq "s") {
                Write-Host "`nDeteniendo servicio Docker..." -ForegroundColor Yellow
                $stopOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['sudo systemctl stop docker']" `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "OK Comando enviado" -ForegroundColor Green
                    
                    Write-Host "`nGenerando trafico para activar las metricas..." -ForegroundColor Yellow
                    for ($i = 1; $i -le 20; $i++) {
                        try {
                            Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 3 | Out-Null
                            Write-Host "." -NoNewline -ForegroundColor Green
                        } catch { 
                            Write-Host "x" -NoNewline -ForegroundColor Red
                        }
                        Start-Sleep -Milliseconds 300
                    }
                    Write-Host "`nOK Trafico generado" -ForegroundColor Green
                    
                    Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 70
                    
                    Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                    Check-Alarm "genius-dev-no-healthy-hosts"
                    
                    Write-Host ""
                    Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                    $openDashboard = Read-Host
                    if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                        $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
                        Start-Process $dashboardUrl
                    }
                }
            }
        }
        elseif ($subOption -eq "C" -or $subOption -eq "c") {
            Write-Host "`nADVERTENCIA CRITICA: Esto detendra contenedores en TODAS las instancias" -ForegroundColor Red
            Write-Host "La aplicacion quedara completamente caida" -ForegroundColor Red
            Write-Host "Continuar? (S/N):" -ForegroundColor Cyan
            $confirm = Read-Host
            
            if ($confirm -eq "S" -or $confirm -eq "s") {
                foreach ($instance in $instances) {
                    $instId = $instance[0]
                    Write-Host "`nDeteniendo contenedores en instancia: $instId" -ForegroundColor Yellow
                    $stopOutput = & aws ssm send-command `
                        --instance-ids $instId `
                        --document-name "AWS-RunShellScript" `
                        --parameters "commands=['sudo docker stop $(sudo docker ps -q)']" `
                        --output json 2>&1 | Out-Null
                }
                
                Write-Host "`nGenerando trafico para activar las metricas..." -ForegroundColor Yellow
                for ($i = 1; $i -le 10; $i++) {
                    try {
                        Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 3 | Out-Null
                    } catch { }
                    Start-Sleep -Milliseconds 500
                }
                
                Write-Host "`nEspera 1-2 minutos para que la alarma se active" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "¿Quieres verificar el estado de la alarma? (S/N)" -ForegroundColor Cyan
                $checkAlarm = Read-Host
                if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
                    Start-Sleep -Seconds 5
                    Check-Alarm "genius-dev-no-healthy-hosts"
                }
            }
        }
    }
    
    "3" {
        # Activar alarma: CPU alta
        Write-Host "`n========================================" -ForegroundColor Cyan
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
                Write-Host "IMPORTANTE:" -ForegroundColor Red
                Write-Host "  - La alarma requiere CPU > 80% durante 1 minuto" -ForegroundColor Yellow
                Write-Host "  - Las metricas de CPU se actualizan cada 60 segundos" -ForegroundColor Yellow
                Write-Host "  - La alarma se activara en aproximadamente 60-90 segundos" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Para detener la carga de CPU:" -ForegroundColor Cyan
                Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
                    Start-Process $dashboardUrl
                }
            } else {
                Write-Host "ERROR Error al iniciar carga de CPU" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR Error al instalar stress-ng" -ForegroundColor Red
        }
    }
    
    "4" {
        # Activar alarma: RAM alta
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "ACTIVAR ALARMA: RAM Alta" -ForegroundColor Red
        Write-Host "Alarma: genius-dev-high-memory" -ForegroundColor Yellow
        Write-Host "Umbral: mem_used_percent > 80% durante 1 minuto" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "IMPORTANTE: Esta metrica requiere CloudWatch Agent instalado" -ForegroundColor Yellow
        Write-Host ""
        
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
            
            Write-Host "`nGenerando carga de RAM por 3 minutos..." -ForegroundColor Yellow
            Write-Host "Esto activara la alarma inmediatamente (1 minuto) con RAM > 80%" -ForegroundColor Cyan
            
            $ramOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['nohup sudo stress-ng --vm 2 --vm-bytes 2G --timeout 180s > /tmp/stress-ng-ram.log 2>&1 &']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OK Comando enviado" -ForegroundColor Green
                
                Write-Host "`nEsperando 70 segundos para que CloudWatch procese las metricas..." -ForegroundColor Yellow
                Start-Sleep -Seconds 70
                
                Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Cyan
                Check-Alarm "genius-dev-high-memory"
                
                Write-Host ""
                Write-Host "IMPORTANTE:" -ForegroundColor Red
                Write-Host "  - La alarma requiere RAM > 80% durante 1 minuto" -ForegroundColor Yellow
                Write-Host "  - Las metricas de RAM requieren CloudWatch Agent" -ForegroundColor Yellow
                Write-Host "  - La alarma se activara en aproximadamente 60-90 segundos" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Para detener la carga de RAM:" -ForegroundColor Cyan
                Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
                
                Write-Host ""
                Write-Host "¿Quieres abrir el dashboard para ver los cambios? (S/N)" -ForegroundColor Cyan
                $openDashboard = Read-Host
                if ($openDashboard -eq "S" -or $openDashboard -eq "s") {
                    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
                    Start-Process $dashboardUrl
                }
            } else {
                Write-Host "ERROR Error al iniciar carga de RAM" -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR Error al instalar stress-ng" -ForegroundColor Red
        }
    }
    
    "5" {
        # Generar trafico para HealthyHostCount
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Generar Trafico para HealthyHostCount" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Cuantas peticiones? (recomendado: 50)" -ForegroundColor Cyan
        $numRequests = Read-Host
        if (-not $numRequests -or $numRequests -eq "") { $numRequests = 50 } else { $numRequests = [int]$numRequests }
        
        $successCount = 0
        $errorCount = 0
        
        Write-Host "`nGenerando peticiones HTTP al ALB..." -ForegroundColor Yellow
        for ($i = 1; $i -le $numRequests; $i++) {
            try {
                $response = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 5
                Write-Host "OK [$i/$numRequests] Status: $($response.StatusCode)" -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "ERROR [$i/$numRequests] Error: $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
            if ($i -lt $numRequests) { Start-Sleep -Milliseconds 500 }
        }
        
        Write-Host "`nOK Prueba completada" -ForegroundColor Green
        Write-Host "  - Peticiones exitosas: $successCount" -ForegroundColor White
        Write-Host "  - Espera 2-5 minutos y verifica el dashboard" -ForegroundColor Yellow
    }
    
    "6" {
        # Verificar todas las alarmas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Estado de Todas las Alarmas CloudWatch" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $alarms = @(
            @{Name="genius-dev-docker-containers-down"; Desc="Contenedores Docker caidos"},
            @{Name="genius-dev-no-healthy-hosts"; Desc="Aplicacion caida"},
            @{Name="genius-dev-high-cpu"; Desc="CPU alta"},
            @{Name="genius-dev-high-memory"; Desc="RAM alta"}
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
