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
Write-Host "Pruebas por Metrica del Dashboard" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "METRICAS DEL DASHBOARD:" -ForegroundColor White
Write-Host "  1. Estado de la Aplicacion (HealthyHostCount) [Alarma: no-healthy-hosts]" -ForegroundColor Yellow
Write-Host "  2. CPU Usage (CPUUtilization) [Alarma: high-cpu]" -ForegroundColor Yellow
Write-Host "  3. RAM Usage (mem_used_percent) [Alarma: high-memory]" -ForegroundColor Yellow
Write-Host ""
Write-Host "PRUEBAS DE FALLO:" -ForegroundColor White
Write-Host "  4. Detener Docker/Aplicacion (simular caida)" -ForegroundColor Red
Write-Host ""
Write-Host "VERIFICACION:" -ForegroundColor White
Write-Host "  5. Verificar estado de alarmas" -ForegroundColor Green
Write-Host ""
Write-Host "Selecciona una opcion (1-5):" -ForegroundColor Cyan
$option = Read-Host

if (-not $option -or $option -eq "") {
    $option = "1"
}

# Ejecutar prueba segun opcion seleccionada
switch ($option) {
    "1" {
        # Prueba: Estado de la Aplicacion (HealthyHostCount)
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: Estado de la Aplicacion" -ForegroundColor Yellow
        Write-Host "Metrica: AWS/ApplicationELB - HealthyHostCount (Average)" -ForegroundColor Yellow
        Write-Host "Widget: 1 - Estado de la Aplicacion" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-no-healthy-hosts (umbral: menor a 1 host saludable)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host 'Objetivo: Generar trafico para verificar que la aplicacion esta activa' -ForegroundColor Cyan
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
        Write-Host "  - Espera 2-5 minutos y verifica Widget 1 y 2" -ForegroundColor Yellow
        Write-Host '  - Deberias ver HealthyHostCount mayor a 0 (aplicacion activa)' -ForegroundColor White
        Write-Host "  - Si HealthyHostCount = 0, la aplicacion esta caida" -ForegroundColor Red
        Write-Host ""
        Write-Host "NOTA: Esta metrica tiene alarma 'genius-dev-no-healthy-hosts'" -ForegroundColor Cyan
        Write-Host "      La alarma se activa cuando HealthyHostCount < 1 (aplicacion caida)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "¿Quieres verificar el estado de la alarma? (S/N)" -ForegroundColor Cyan
        $checkAlarm = Read-Host
        if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
            Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Yellow
            try {
                $alarmOutput = & aws cloudwatch describe-alarms --alarm-names "genius-dev-no-healthy-hosts" --query 'MetricAlarms[0]' --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
                    if ($alarm) {
                        $state = $alarm.StateValue
                        $color = switch ($state) {
                            "OK" { "Green" }
                            "ALARM" { "Red" }
                            default { "Yellow" }
                        }
                        Write-Host "  Estado actual: $state" -ForegroundColor $color
                        Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                        Write-Host "  Umbral: HealthyHostCount < 1" -ForegroundColor Gray
                    } else {
                        Write-Host "  ERROR Alarma no encontrada" -ForegroundColor Red
                        Write-Host "  Ejecuta 'terraform apply' para crear la alarma" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  ERROR No se pudo consultar la alarma" -ForegroundColor Red
                }
            } catch {
                Write-Host "  ERROR: $_" -ForegroundColor Red
            }
        }
    }
    
    "2" {
        # Prueba: CPUUtilization
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: CPU Usage" -ForegroundColor Yellow
        Write-Host "Metrica: AWS/EC2 - CPUUtilization (Average)" -ForegroundColor Yellow
        Write-Host "Widget: 2 - CPU Usage (%)" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-high-cpu (umbral: mayor a 80% durante 10 min)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Objetivo: Generar carga de CPU al 100% para activar metrica y alarma" -ForegroundColor Cyan
        Write-Host ""
        
        # Obtener instancias
        Write-Host "Obteniendo instancias EC2..." -ForegroundColor Yellow
        try {
            $instancesOutput = & aws ec2 describe-instances `
                --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
                --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $instancesJson = $instancesOutput -join "`n"
            } else {
                $instancesJson = $null
            }
            
            if (-not $instancesJson) {
                Write-Host "ERROR Error: No se encontraron instancias o AWS CLI no esta configurado" -ForegroundColor Red
                break
            }
            
            $instances = $instancesJson | ConvertFrom-Json
            if ($instances.Count -eq 0) {
                Write-Host "ERROR Error: No se encontraron instancias en ejecucion" -ForegroundColor Red
                break
            }
            
            Write-Host "OK Instancias encontradas:" -ForegroundColor Green
            $instances | ForEach-Object { Write-Host "  - Instance ID: $($_[0]) - IP: $($_[1])" -ForegroundColor White }
            
            $instanceId = $instances[0][0]
            Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
            
            # Instalar stress-ng
            Write-Host "`nInstalando stress-ng..." -ForegroundColor Yellow
            $installOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['sudo yum install -y stress-ng']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installResult = ($installOutput -join "`n") | ConvertFrom-Json
            } else {
                $installResult = $null
            }
            
            if ($installResult) {
                Start-Sleep -Seconds 5
                Write-Host "OK stress-ng instalado" -ForegroundColor Green
                
                # Generar carga de CPU
                Write-Host "`nGenerando carga de CPU al 100% por 10 minutos..." -ForegroundColor Yellow
                Write-Host "Esto se ejecutara en segundo plano en la instancia." -ForegroundColor Cyan
                
                $cpuOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 600s > /tmp/stress-ng.log 2>&1 &']" `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $cpuResult = ($cpuOutput -join "`n") | ConvertFrom-Json
                } else {
                    $cpuResult = $null
                }
                
                if ($cpuResult) {
                    $cpuCommandId = $cpuResult.Command.CommandId
                    Write-Host "OK Comando enviado (Command ID: $cpuCommandId)" -ForegroundColor Green
                    
                    # Esperar un poco y verificar que el comando se ejecuto
                    Write-Host "`nVerificando que el comando se ejecuto correctamente..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                    
                    try {
                        $verifyOutput = & aws ssm get-command-invocation `
                            --command-id $cpuCommandId `
                            --instance-id $instanceId `
                            --output json 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $verify = ($verifyOutput -join "`n") | ConvertFrom-Json
                            if ($verify.Status -eq "Success" -or $verify.Status -eq "InProgress") {
                                Write-Host "OK Comando ejecutandose correctamente" -ForegroundColor Green
                                
                                # Verificar si stress-ng esta corriendo
                                $checkOutput = & aws ssm send-command `
                                    --instance-ids $instanceId `
                                    --document-name "AWS-RunShellScript" `
                                    --parameters "commands=['ps aux | grep stress-ng | grep -v grep']" `
                                    --output json 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    $checkResult = ($checkOutput -join "`n") | ConvertFrom-Json
                                    $checkCommandId = $checkResult.Command.CommandId
                                    Start-Sleep -Seconds 3
                                    
                                    $checkStatusOutput = & aws ssm get-command-invocation `
                                        --command-id $checkCommandId `
                                        --instance-id $instanceId `
                                        --output json 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $checkStatus = ($checkStatusOutput -join "`n") | ConvertFrom-Json
                                        if ($checkStatus.Status -eq "Success") {
                                            $processOutput = $checkStatus.StandardOutputContent.Trim()
                                            if ($processOutput -and $processOutput -ne "") {
                                                Write-Host "OK stress-ng esta corriendo" -ForegroundColor Green
                                            } else {
                                                Write-Host "ADV stress-ng puede no estar corriendo. Verifica manualmente." -ForegroundColor Yellow
                                            }
                                        }
                                    }
                                }
                            } else {
                                Write-Host "ADV Estado del comando: $($verify.Status)" -ForegroundColor Yellow
                                if ($verify.StandardErrorContent) {
                                    Write-Host "Error: $($verify.StandardErrorContent)" -ForegroundColor Red
                                }
                            }
                        }
                    } catch {
                        Write-Host "ADV No se pudo verificar el estado del comando: $_" -ForegroundColor Yellow
                    }
                    
                    Write-Host "`nEspera 5-10 minutos para que:" -ForegroundColor Yellow
                    Write-Host "  - Las metricas se actualicen en CloudWatch (periodo: 5 minutos)" -ForegroundColor White
                    Write-Host "  - Widget 3 muestre CPU cerca de 100%" -ForegroundColor White
                    Write-Host "  - La alarma se active (despues de 10 minutos con CPU > 80%)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "IMPORTANTE:" -ForegroundColor Red
                    Write-Host "  - Las metricas de CPU se agregan por AutoScalingGroupName" -ForegroundColor Yellow
                    Write-Host "  - El periodo de la metrica es de 5 minutos (300 segundos)" -ForegroundColor Yellow
                    Write-Host "  - Puede tardar 5-10 minutos en aparecer en el dashboard" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Para verificar el estado:" -ForegroundColor Cyan
                    Write-Host "  .\verificar-cpu.ps1" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Para detener la carga:" -ForegroundColor Cyan
                    Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
                    
                    Write-Host ""
                    Write-Host "¿Quieres verificar el estado de la alarma? (S/N)" -ForegroundColor Cyan
                    $checkAlarm = Read-Host
                    if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
                        Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Yellow
                        try {
                            $alarmOutput = & aws cloudwatch describe-alarms --alarm-names "genius-dev-high-cpu" --query 'MetricAlarms[0]' --output json 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
                                if ($alarm) {
                                    $state = $alarm.StateValue
                                    $color = switch ($state) {
                                        "OK" { "Green" }
                                        "ALARM" { "Red" }
                                        default { "Yellow" }
                                    }
                                    Write-Host "  Estado actual: $state" -ForegroundColor $color
                                    Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                                    Write-Host "  Umbral: CPU > 80% durante 10 minutos" -ForegroundColor Gray
                                    Write-Host ""
                                    Write-Host "NOTA: La alarma puede tardar 10 minutos en actualizarse" -ForegroundColor Yellow
                                } else {
                                    Write-Host "  ERROR Alarma no encontrada" -ForegroundColor Red
                                }
                            } else {
                                Write-Host "  ERROR No se pudo consultar la alarma" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "  ERROR: $_" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "ERROR Error al iniciar carga de CPU. Verifica permisos SSM." -ForegroundColor Red
                }
            } else {
                Write-Host "ERROR Error al instalar stress-ng. Verifica permisos SSM." -ForegroundColor Red
            }
        } catch {
            Write-Host "ERROR Error: $_" -ForegroundColor Red
        }
    }
    
    "3" {
        # Prueba: RAM Usage
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: RAM Usage" -ForegroundColor Yellow
        Write-Host "Metrica: CWAgent - mem_used_percent (Average)" -ForegroundColor Yellow
        Write-Host "Widget: 3 - RAM Usage (%)" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-high-memory (umbral: mayor a 80% durante 10 min)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Objetivo: Generar carga de RAM para activar metrica y alarma" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IMPORTANTE: Esta metrica requiere CloudWatch Agent instalado" -ForegroundColor Yellow
        Write-Host "  Si no ves datos, verifica que CloudWatch Agent este corriendo" -ForegroundColor Yellow
        Write-Host ""
        
        # Obtener instancias
        Write-Host "Obteniendo instancias EC2..." -ForegroundColor Yellow
        try {
            $instancesOutput = & aws ec2 describe-instances `
                --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
                --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $instancesJson = $instancesOutput -join "`n"
            } else {
                $instancesJson = $null
            }
            
            if (-not $instancesJson) {
                Write-Host "ERROR Error: No se encontraron instancias o AWS CLI no esta configurado" -ForegroundColor Red
                break
            }
            
            $instances = $instancesJson | ConvertFrom-Json
            if ($instances.Count -eq 0) {
                Write-Host "ERROR Error: No se encontraron instancias en ejecucion" -ForegroundColor Red
                break
            }
            
            Write-Host "OK Instancias encontradas:" -ForegroundColor Green
            $instances | ForEach-Object { Write-Host "  - Instance ID: $($_[0]) - IP: $($_[1])" -ForegroundColor White }
            
            $instanceId = $instances[0][0]
            Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
            
            # Verificar si CloudWatch Agent esta instalado
            Write-Host "`nVerificando CloudWatch Agent..." -ForegroundColor Yellow
            $checkAgentOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['systemctl status amazon-cloudwatch-agent | grep Active']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $checkAgentResult = ($checkAgentOutput -join "`n") | ConvertFrom-Json
                $checkAgentCommandId = $checkAgentResult.Command.CommandId
                Start-Sleep -Seconds 3
                
                $checkAgentStatusOutput = & aws ssm get-command-invocation `
                    --command-id $checkAgentCommandId `
                    --instance-id $instanceId `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $checkAgentStatus = ($checkAgentStatusOutput -join "`n") | ConvertFrom-Json
                    if ($checkAgentStatus.Status -eq "Success") {
                        $agentStatus = $checkAgentStatus.StandardOutputContent.Trim()
                        if ($agentStatus -and $agentStatus -like "*active*") {
                            Write-Host "OK CloudWatch Agent esta corriendo" -ForegroundColor Green
                        } else {
                            Write-Host "ADV CloudWatch Agent puede no estar corriendo" -ForegroundColor Yellow
                            Write-Host "  Las metricas de RAM pueden no aparecer" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            # Instalar stress-ng si no esta instalado
            Write-Host "`nInstalando stress-ng..." -ForegroundColor Yellow
            $installOutput = & aws ssm send-command `
                --instance-ids $instanceId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['sudo yum install -y stress-ng']" `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installResult = ($installOutput -join "`n") | ConvertFrom-Json
            } else {
                $installResult = $null
            }
            
            if ($installResult) {
                Start-Sleep -Seconds 5
                Write-Host "OK stress-ng instalado" -ForegroundColor Green
                
                # Generar carga de RAM
                Write-Host "`nGenerando carga de RAM por 10 minutos..." -ForegroundColor Yellow
                Write-Host "Esto se ejecutara en segundo plano en la instancia." -ForegroundColor Cyan
                
                $ramOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['nohup sudo stress-ng --vm 2 --vm-bytes 2G --timeout 600s > /tmp/stress-ng-ram.log 2>&1 &']" `
                    --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $ramResult = ($ramOutput -join "`n") | ConvertFrom-Json
                } else {
                    $ramResult = $null
                }
                
                if ($ramResult) {
                    $ramCommandId = $ramResult.Command.CommandId
                    Write-Host "OK Comando enviado (Command ID: $ramCommandId)" -ForegroundColor Green
                    
                    Write-Host "`nEspera 5-10 minutos para que:" -ForegroundColor Yellow
                    Write-Host "  - Las metricas se actualicen en CloudWatch (periodo: 5 minutos)" -ForegroundColor White
                    Write-Host "  - Widget 4 muestre RAM cerca de 100%" -ForegroundColor White
                    Write-Host "  - La alarma se active (despues de 10 minutos con RAM > 80%)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "IMPORTANTE:" -ForegroundColor Red
                    Write-Host "  - Las metricas de RAM requieren CloudWatch Agent" -ForegroundColor Yellow
                    Write-Host "  - El periodo de la metrica es de 5 minutos (300 segundos)" -ForegroundColor Yellow
                    Write-Host "  - Puede tardar 5-10 minutos en aparecer en el dashboard" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Para detener la carga:" -ForegroundColor Cyan
                    Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo pkill stress-ng\"]'" -ForegroundColor White
                    
                    Write-Host ""
                    Write-Host "¿Quieres verificar el estado de la alarma? (S/N)" -ForegroundColor Cyan
                    $checkAlarm = Read-Host
                    if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
                        Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Yellow
                        try {
                            $alarmOutput = & aws cloudwatch describe-alarms --alarm-names "genius-dev-high-memory" --query 'MetricAlarms[0]' --output json 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
                                if ($alarm) {
                                    $state = $alarm.StateValue
                                    $color = switch ($state) {
                                        "OK" { "Green" }
                                        "ALARM" { "Red" }
                                        default { "Yellow" }
                                    }
                                    Write-Host "  Estado actual: $state" -ForegroundColor $color
                                    Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                                    Write-Host "  Umbral: RAM > 80% durante 10 minutos" -ForegroundColor Gray
                                    Write-Host ""
                                    Write-Host "NOTA: La alarma puede tardar 10 minutos en actualizarse" -ForegroundColor Yellow
                                } else {
                                    Write-Host "  ERROR Alarma no encontrada" -ForegroundColor Red
                                    Write-Host "  Ejecuta 'terraform apply' para crear la alarma" -ForegroundColor Yellow
                                }
                            } else {
                                Write-Host "  ERROR No se pudo consultar la alarma" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "  ERROR: $_" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "ERROR Error al iniciar carga de RAM. Verifica permisos SSM." -ForegroundColor Red
                }
            } else {
                Write-Host "ERROR Error al instalar stress-ng. Verifica permisos SSM." -ForegroundColor Red
            }
        } catch {
            Write-Host "ERROR Error: $_" -ForegroundColor Red
        }
    }
    
    "4" {
        # Prueba: Detener Docker/Aplicacion (simular caida)
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: Detener Docker/Aplicacion" -ForegroundColor Red
        Write-Host "Objetivo: Simular caida de aplicacion para ver cambio en dashboard" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "IMPORTANTE: Esta prueba detendra Docker o el servicio en una instancia" -ForegroundColor Red
        Write-Host "Esto causara que HealthyHostCount baje a 0 y la alarma se active" -ForegroundColor Yellow
        Write-Host ""
        
        # Obtener instancias
        Write-Host "Obteniendo instancias EC2..." -ForegroundColor Yellow
        try {
            $instancesOutput = & aws ec2 describe-instances `
                --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
                --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $instancesJson = $instancesOutput -join "`n"
            } else {
                $instancesJson = $null
            }
            
            if (-not $instancesJson) {
                Write-Host "ERROR Error: No se encontraron instancias o AWS CLI no esta configurado" -ForegroundColor Red
                break
            }
            
            $instances = $instancesJson | ConvertFrom-Json
            if ($instances.Count -eq 0) {
                Write-Host "ERROR Error: No se encontraron instancias en ejecucion" -ForegroundColor Red
                break
            }
            
            Write-Host "OK Instancias encontradas:" -ForegroundColor Green
            $instances | ForEach-Object { Write-Host "  - Instance ID: $($_[0]) - IP: $($_[1])" -ForegroundColor White }
            
            $instanceId = $instances[0][0]
            Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Cyan
            
            Write-Host "`nOpciones para detener la aplicacion:" -ForegroundColor Yellow
            Write-Host "  A) Detener todos los contenedores Docker (docker stop)" -ForegroundColor White
            Write-Host "  B) Detener el servicio Docker (systemctl stop docker)" -ForegroundColor White
            Write-Host "  C) Detener un contenedor especifico (requiere nombre)" -ForegroundColor White
            Write-Host "  D) Solo verificar estado actual (sin modificar)" -ForegroundColor White
            Write-Host ""
            Write-Host "Selecciona opcion (A/B/C/D):" -ForegroundColor Cyan
            $subOption = Read-Host
            
            if ($subOption -eq "A" -or $subOption -eq "a") {
                Write-Host "`nADVERTENCIA: Esto detendra TODOS los contenedores Docker" -ForegroundColor Red
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
                        $stopCommandId = $stopResult.Command.CommandId
                        Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
                        
                        Write-Host "`nEspera 1-2 minutos para que:" -ForegroundColor Yellow
                        Write-Host "  - El ALB detecte que el health check falla" -ForegroundColor White
                        Write-Host "  - HealthyHostCount baje a 0 en el dashboard" -ForegroundColor White
                        Write-Host "  - La alarma 'genius-dev-no-healthy-hosts' se active" -ForegroundColor White
                        Write-Host ""
                        Write-Host "Para restaurar la aplicacion:" -ForegroundColor Cyan
                        Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo docker start $(sudo docker ps -aq)\"]'" -ForegroundColor White
                    } else {
                        Write-Host "ERROR Error al detener contenedores. Verifica permisos SSM." -ForegroundColor Red
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
                        $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                        $stopCommandId = $stopResult.Command.CommandId
                        Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
                        
                        Write-Host "`nEspera 1-2 minutos para que:" -ForegroundColor Yellow
                        Write-Host "  - El ALB detecte que el health check falla" -ForegroundColor White
                        Write-Host "  - HealthyHostCount baje a 0 en el dashboard" -ForegroundColor White
                        Write-Host "  - La alarma 'genius-dev-no-healthy-hosts' se active" -ForegroundColor White
                        Write-Host ""
                        Write-Host "Para restaurar Docker:" -ForegroundColor Cyan
                        Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo systemctl start docker\"]'" -ForegroundColor White
                    } else {
                        Write-Host "ERROR Error al detener Docker. Verifica permisos SSM." -ForegroundColor Red
                    }
                }
            }
            elseif ($subOption -eq "C" -or $subOption -eq "c") {
                Write-Host "`nIngresa el nombre del contenedor Docker a detener:" -ForegroundColor Cyan
                $containerName = Read-Host
                
                if ($containerName) {
                    Write-Host "`nDeteniendo contenedor: $containerName" -ForegroundColor Yellow
                    $stopOutput = & aws ssm send-command `
                        --instance-ids $instanceId `
                        --document-name "AWS-RunShellScript" `
                        --parameters "commands=[\"sudo docker stop $containerName\"]" `
                        --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $stopResult = ($stopOutput -join "`n") | ConvertFrom-Json
                        $stopCommandId = $stopResult.Command.CommandId
                        Write-Host "OK Comando enviado (Command ID: $stopCommandId)" -ForegroundColor Green
                        
                        Write-Host "`nEspera 1-2 minutos para ver el cambio en el dashboard" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Para restaurar el contenedor:" -ForegroundColor Cyan
                        Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo docker start $containerName\"]'" -ForegroundColor White
                    } else {
                        Write-Host "ERROR Error al detener contenedor. Verifica permisos SSM." -ForegroundColor Red
                    }
                } else {
                    Write-Host "ERROR Nombre de contenedor no especificado" -ForegroundColor Red
                }
            }
            else {
                Write-Host "`nVerificando estado actual de contenedores Docker..." -ForegroundColor Yellow
                $statusOutput = & aws ssm send-command `
                    --instance-ids $instanceId `
                    --document-name "AWS-RunShellScript" `
                    --parameters "commands=['sudo docker ps']" `
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
                            Write-Host "`nContenedores Docker en ejecucion:" -ForegroundColor Green
                            Write-Host $statusCheck.StandardOutputContent -ForegroundColor White
                        }
                    }
                }
            }
            
            Write-Host ""
            Write-Host "¿Quieres verificar el estado de la alarma ahora? (S/N)" -ForegroundColor Cyan
            $checkAlarm = Read-Host
            if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
                Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Yellow
                try {
                    $alarmOutput = & aws cloudwatch describe-alarms --alarm-names "genius-dev-no-healthy-hosts" --query 'MetricAlarms[0]' --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
                        if ($alarm) {
                            $state = $alarm.StateValue
                            $color = switch ($state) {
                                "OK" { "Green" }
                                "ALARM" { "Red" }
                                default { "Yellow" }
                            }
                            Write-Host "  Estado actual: $state" -ForegroundColor $color
                            Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "NOTA: La alarma puede tardar 1-2 minutos en actualizarse" -ForegroundColor Yellow
                            Write-Host "      Despues de detener Docker, espera y verifica de nuevo" -ForegroundColor Yellow
                        } else {
                            Write-Host "  ERROR Alarma no encontrada" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "  ERROR No se pudo consultar la alarma" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  ERROR: $_" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "ERROR Error: $_" -ForegroundColor Red
        }
    }
    
    "5" {
        # Verificar alarmas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Estado de Alarmas CloudWatch" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $alarms = @(
            "genius-dev-no-healthy-hosts",
            "genius-dev-high-cpu",
            "genius-dev-high-memory"
        )
        
        foreach ($alarmName in $alarms) {
            Write-Host "Verificando: $alarmName..." -ForegroundColor Yellow
            try {
                $alarmOutput = & aws cloudwatch describe-alarms --alarm-names $alarmName --query 'MetricAlarms[0]' --output json 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $alarm = ($alarmOutput -join "`n") | ConvertFrom-Json
                } else {
                    $alarm = $null
                }
                if ($alarm) {
                    $state = $alarm.StateValue
                    $color = switch ($state) {
                        "OK" { "Green" }
                        "ALARM" { "Red" }
                        default { "Yellow" }
                    }
                    Write-Host "  Estado: $state" -ForegroundColor $color
                    Write-Host "  Razon: $($alarm.StateReason)" -ForegroundColor Gray
                } else {
                    Write-Host "  ADV Alarma no encontrada" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  ERROR Error al consultar: $_" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
    
    default {
        Write-Host "Opcion invalida. Ejecutando prueba basica..." -ForegroundColor Yellow
        $option = "1"
    }
}

# Mostrar resumen solo si se ejecuto prueba de trafico
if ($option -eq "1") {
    if (Get-Variable -Name successCount -ErrorAction SilentlyContinue) {
        if ($null -ne $successCount) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Resumen" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Peticiones exitosas: $successCount" -ForegroundColor Green
            if (Get-Variable -Name errorCount -ErrorAction SilentlyContinue) {
                if ($null -ne $errorCount) {
                    Write-Host "Peticiones fallidas: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Gray" })
                }
            }
            if (Get-Variable -Name numRequests -ErrorAction SilentlyContinue) {
                if ($null -ne $numRequests) {
                    Write-Host "Total: $numRequests" -ForegroundColor Cyan
                }
            }
        }
    }
}

# Mostrar instrucciones segun la prueba ejecutada
if ($option -ne "4" -and $option -ne "5") {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Proximos pasos" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $waitTime = switch ($option) {
        "1" { "2-5 minutos" }
        "2" { "10-15 minutos" }
        "3" { "10-15 minutos" }
        default { "2-5 minutos" }
    }
    
    Write-Host "1. Espera $waitTime para que las metricas se actualicen" -ForegroundColor Yellow
    Write-Host "2. Ve a CloudWatch Dashboards" -ForegroundColor Yellow
    Write-Host "3. Abre el dashboard: genius-dev-application-status" -ForegroundColor Yellow
    Write-Host "4. Actualiza la pagina (F5) despues de esperar" -ForegroundColor Yellow
    
    Write-Host "`nWidgets a verificar:" -ForegroundColor Cyan
    switch ($option) {
        "1" {
            Write-Host "  - Widget 1: Estado de la Aplicacion (numero de hosts saludables)" -ForegroundColor White
            Write-Host "  - Widget 2: Historial de HealthyHostCount" -ForegroundColor White
            Write-Host "    Si HealthyHostCount = 0: Aplicacion caida" -ForegroundColor Red
            Write-Host "    Si HealthyHostCount >= 1: Aplicacion activa" -ForegroundColor Green
        }
        "2" {
            Write-Host "  - Widget 3: CPU Usage (%)" -ForegroundColor White
            Write-Host "  - Alarma: genius-dev-high-cpu" -ForegroundColor White
        }
        "3" {
            Write-Host "  - Widget 4: RAM Usage (%)" -ForegroundColor White
            Write-Host "  - Alarma: genius-dev-high-memory" -ForegroundColor White
            Write-Host "  - NOTA: Requiere CloudWatch Agent instalado" -ForegroundColor Yellow
        }
        "4" {
            Write-Host "  - Widget 1: Estado de la Aplicacion (debera mostrar 0)" -ForegroundColor White
            Write-Host "  - Widget 2: Historial (debera mostrar caida)" -ForegroundColor White
            Write-Host "  - Alarma: genius-dev-no-healthy-hosts (debera activarse)" -ForegroundColor Red
        }
    }
    
    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
    Write-Host "`nDashboard URL:" -ForegroundColor Cyan
    Write-Host $dashboardUrl -ForegroundColor White
    
    Write-Host "`n¿Quieres abrir el dashboard en tu navegador? (S/N)" -ForegroundColor Cyan
    $openBrowser = Read-Host
    if ($openBrowser -eq "S" -or $openBrowser -eq "s" -or $openBrowser -eq "Y" -or $openBrowser -eq "y") {
        Start-Process $dashboardUrl
    }
    
    Write-Host "`nListo! Revisa CloudWatch en unos minutos." -ForegroundColor Green
}
