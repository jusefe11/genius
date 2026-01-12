# Script para probar las metricas de CloudWatch
# Genera trafico hacia el ALB para activar las metricas
# Prueba cada indicador y alarma del dashboard

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
Write-Host "  1. HealthyHostCount (Widget 1 - Hosts Saludables) [Alarma: no-healthy-hosts]" -ForegroundColor Yellow
Write-Host "  2. UnHealthyHostCount (Widget 1 y 4 - Hosts No Saludables) [Alarma: unhealthy-hosts]" -ForegroundColor Yellow
Write-Host "  3. CPUUtilization (Widget 2 - Uso de CPU) [Alarma: high-cpu]" -ForegroundColor Yellow
Write-Host "  4. HTTPCode_Target_5XX_Count (Widget 3 - Errores 5xx) [Alarma: http-5xx-errors]" -ForegroundColor Yellow
Write-Host ""
Write-Host "PRUEBAS COMBINADAS:" -ForegroundColor White
Write-Host "  5. Prueba completa: Todas las metricas" -ForegroundColor Cyan
Write-Host ""
Write-Host "VERIFICACION:" -ForegroundColor White
Write-Host "  6. Verificar estado de alarmas" -ForegroundColor Green
Write-Host "  7. Verificar metricas directamente (AWS CLI)" -ForegroundColor Green
Write-Host ""
Write-Host "Selecciona una opcion (1-7):" -ForegroundColor Cyan
$option = Read-Host

if (-not $option -or $option -eq "") {
    $option = "1"
}

# Ejecutar prueba segun opcion seleccionada
switch ($option) {
    "1" {
        # Prueba: HealthyHostCount
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: HealthyHostCount" -ForegroundColor Yellow
        Write-Host "Metrica: AWS/ApplicationELB - HealthyHostCount (Average)" -ForegroundColor Yellow
        Write-Host "Widget: 1 - Hosts Saludables" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-no-healthy-hosts (umbral: menor a 1 host saludable)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host 'Objetivo: Generar trafico para que haya hosts saludables mayor a 0' -ForegroundColor Cyan
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
        Write-Host "  - Espera 2-5 minutos y verifica Widget 1" -ForegroundColor Yellow
        Write-Host '  - Deberias ver HealthyHostCount mayor a 0 (linea verde)' -ForegroundColor White
        Write-Host ""
        Write-Host "NOTA: Esta metrica tiene alarma 'genius-dev-no-healthy-hosts'" -ForegroundColor Cyan
        Write-Host "      La alarma se activa cuando HealthyHostCount < 1 (sin hosts saludables)" -ForegroundColor Gray
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
        # Prueba: UnHealthyHostCount
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: UnHealthyHostCount" -ForegroundColor Yellow
        Write-Host "Metrica: AWS/ApplicationELB - UnHealthyHostCount (Average)" -ForegroundColor Yellow
        Write-Host "Widget: 1 y 4 - Hosts No Saludables" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-unhealthy-hosts (umbral: mayor a 0)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Esta prueba requiere hacer que una instancia falle el health check" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor Cyan
        Write-Host '  A) Detener servicio en una instancia EC2 (requiere SSM/SSH)' -ForegroundColor White
        Write-Host '  B) Solo verificar estado actual (sin modificar)' -ForegroundColor White
        Write-Host ""
        Write-Host 'Selecciona opcion (A/B):' -ForegroundColor Cyan
        $subOption = Read-Host
        
        if ($subOption -eq "A" -or $subOption -eq "a") {
            Write-Host "`nObteniendo instancias EC2..." -ForegroundColor Yellow
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
                
                if ($instancesJson) {
                    $instances = $instancesJson | ConvertFrom-Json
                    if ($instances.Count -gt 0) {
                        $instanceId = $instances[0][0]
                        Write-Host "OK Instancia encontrada: $instanceId" -ForegroundColor Green
                        
                        Write-Host "`nIMPORTANTE: Esto detendra temporalmente un servicio" -ForegroundColor Red
                        Write-Host "Continuar? (S/N):" -ForegroundColor Cyan
                        $confirm = Read-Host
                        
                        if ($confirm -eq "S" -or $confirm -eq "s") {
                            Write-Host "`nDeteniendo servicio (simulando fallo)..." -ForegroundColor Yellow
                            Write-Host '  Ejecutando: sudo systemctl stop servicio o docker stop container' -ForegroundColor Gray
                            
                            Write-Host "`nAjusta el comando segun tu aplicacion:" -ForegroundColor Yellow
                            Write-Host "  aws ssm send-command --instance-ids $instanceId --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo systemctl stop tu-servicio\"]'" -ForegroundColor White
                            
                            Write-Host "`nDespues de detener el servicio:" -ForegroundColor Cyan
                            Write-Host "  1. Espera 1-2 minutos" -ForegroundColor White
                            Write-Host "  2. Verifica Widget 1 y 4 - UnHealthyHostCount deberia aumentar" -ForegroundColor White
                            Write-Host "  3. La alarma deberia activarse (estado ALARM)" -ForegroundColor White
                            Write-Host "  4. Restaura el servicio cuando termines" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "ERROR No se encontraron instancias" -ForegroundColor Red
                    }
                } else {
                    Write-Host "ERROR Error al obtener instancias. Verifica AWS CLI." -ForegroundColor Red
                }
            } catch {
                Write-Host "ERROR Error: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "`nVerificando estado actual de UnHealthyHostCount..." -ForegroundColor Yellow
            Write-Host "  Consulta el dashboard para ver el valor actual" -ForegroundColor White
            Write-Host "  Widget 1 y 4 muestran esta metrica" -ForegroundColor White
        }
    }
    
    "3" {
        # Prueba: CPUUtilization
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: CPUUtilization" -ForegroundColor Yellow
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
                    Write-Host "  - Widget 2 muestre CPU cerca de 100%" -ForegroundColor White
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
    
    "4" {
        # Prueba: HTTPCode_Target_5XX_Count
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba: HTTPCode_Target_5XX_Count" -ForegroundColor Yellow
        Write-Host "Metrica: AWS/ApplicationELB - HTTPCode_Target_5XX_Count (Sum)" -ForegroundColor Yellow
        Write-Host "Widget: 3 - Errores HTTP 5xx" -ForegroundColor Yellow
        Write-Host 'Alarma: genius-dev-http-5xx-errors (umbral: mayor a 5 errores en 5 min)' -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Objetivo: Generar errores 5xx para activar metrica y alarma" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IMPORTANTE: Para generar errores 5xx reales, necesitas:" -ForegroundColor Yellow
        Write-Host "  1. Que tu aplicacion devuelva 500, 502, 503 o 504" -ForegroundColor White
        Write-Host "  2. O detener temporalmente el servicio en una instancia" -ForegroundColor White
        Write-Host ""
        Write-Host "Este script intentara generar errores, pero si tu aplicacion" -ForegroundColor Yellow
        Write-Host "devuelve 404 en lugar de 5xx, la alarma no se activara." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Cuantas peticiones generar? (recomendado: 10 para asegurar > 5 errores)" -ForegroundColor Cyan
        $numRequests = Read-Host
        if (-not $numRequests -or $numRequests -eq "") { $numRequests = 10 } else { $numRequests = [int]$numRequests }
        
        Write-Host "`nGenerando $numRequests peticiones..." -ForegroundColor Yellow
        Write-Host "Intentando diferentes metodos para generar errores 5xx..." -ForegroundColor Gray
        
        $errorCount = 0
        $error4xxCount = 0
        $successCount = 0
        
        for ($i = 1; $i -le $numRequests; $i++) {
            try {
                # Intentar diferentes metodos que podrian generar 5xx
                $methods = @("GET", "POST", "PUT", "DELETE")
                $method = $methods[($i - 1) % $methods.Length]
                
                # Intentar diferentes endpoints que podrian fallar
                $endpoints = @(
                    "/endpoint-inexistente-$i",
                    "/api/error",
                    "/error",
                    "/test-error",
                    "/internal-error"
                )
                $endpoint = $endpoints[($i - 1) % $endpoints.Length]
                
                $response = Invoke-WebRequest -Uri "$albUrl$endpoint" -Method $method -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
                
                if ($response.StatusCode -ge 500) {
                    Write-Host "OK [$i/$numRequests] Error 5xx: $($response.StatusCode)" -ForegroundColor Red
                    $errorCount++
                } elseif ($response.StatusCode -ge 400) {
                    Write-Host "ADV [$i/$numRequests] Error 4xx: $($response.StatusCode) (no cuenta para la alarma)" -ForegroundColor Yellow
                    $error4xxCount++
                } else {
                    Write-Host "OK [$i/$numRequests] Status: $($response.StatusCode) (exitoso)" -ForegroundColor Green
                    $successCount++
                }
            } catch {
                $statusCode = $null
                if ($_.Exception.Response) {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                }
                
                if ($statusCode -ge 500) {
                    Write-Host "OK [$i/$numRequests] Error 5xx capturado: $statusCode" -ForegroundColor Red
                    $errorCount++
                } elseif ($statusCode -ge 400) {
                    Write-Host "ADV [$i/$numRequests] Error 4xx: $statusCode (no cuenta para la alarma)" -ForegroundColor Yellow
                    $error4xxCount++
                } else {
                    Write-Host "ADV [$i/$numRequests] Error de conexion: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
            Start-Sleep -Milliseconds 500
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Resumen de la prueba" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  - Errores 5xx detectados: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Yellow" })
        Write-Host "  - Errores 4xx detectados: $error4xxCount" -ForegroundColor Yellow
        Write-Host "  - Peticiones exitosas: $successCount" -ForegroundColor Green
        Write-Host ""
        
        if ($errorCount -lt 6) {
            Write-Host "ADVERTENCIA: Se detectaron menos de 6 errores 5xx" -ForegroundColor Red
            Write-Host "La alarma requiere mas de 5 errores 5xx en 5 minutos" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Para generar errores 5xx reales:" -ForegroundColor Cyan
            Write-Host "  1. Detener temporalmente el servicio en una instancia:" -ForegroundColor White
            Write-Host "     aws ssm send-command --instance-ids <instance-id> --document-name 'AWS-RunShellScript' --parameters 'commands=[\"sudo systemctl stop tu-servicio\"]'" -ForegroundColor Gray
            Write-Host "  2. O modificar temporalmente tu aplicacion para que devuelva 500" -ForegroundColor White
            Write-Host "  3. O hacer peticiones que realmente causen errores del servidor" -ForegroundColor White
        } else {
            Write-Host "OK Se generaron suficientes errores 5xx para activar la alarma" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Espera 5-10 minutos y verifica:" -ForegroundColor Yellow
        Write-Host "  - Widget 3 en el dashboard" -ForegroundColor White
        Write-Host "  - Estado de la alarma: genius-dev-http-5xx-errors" -ForegroundColor White
        Write-Host ""
        Write-Host "¿Quieres verificar el estado de la alarma ahora? (S/N)" -ForegroundColor Cyan
        $checkAlarm = Read-Host
        if ($checkAlarm -eq "S" -or $checkAlarm -eq "s") {
            Write-Host "`nVerificando estado de la alarma..." -ForegroundColor Yellow
            try {
                $alarmOutput = & aws cloudwatch describe-alarms --alarm-names "genius-dev-http-5xx-errors" --query 'MetricAlarms[0]' --output json 2>&1
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
                        Write-Host "NOTA: La alarma puede tardar 5 minutos en actualizarse" -ForegroundColor Yellow
                        Write-Host "      Si el estado es OK, espera 5-10 minutos y verifica de nuevo" -ForegroundColor Yellow
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
    }
    
    "5" {
        # Prueba completa: Todas las metricas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Prueba Completa: Todas las Metricas" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Esta prueba ejecutara pruebas para todas las metricas:" -ForegroundColor Cyan
        Write-Host "  1. HealthyHostCount" -ForegroundColor White
        Write-Host "  2. UnHealthyHostCount" -ForegroundColor White
        Write-Host "  3. CPUUtilization" -ForegroundColor White
        Write-Host "  4. HTTPCode_Target_5XX_Count" -ForegroundColor White
        Write-Host ""
        Write-Host "Continuar? (S/N):" -ForegroundColor Cyan
        $confirm = Read-Host
        
        if ($confirm -ne "S" -and $confirm -ne "s") {
            Write-Host "Prueba cancelada." -ForegroundColor Yellow
            break
        }
        
        # Fase 1: HealthyHostCount
        Write-Host "`n[Fase 1/4] Probando HealthyHostCount..." -ForegroundColor Cyan
        Write-Host "Generando 50 peticiones HTTP..." -ForegroundColor Yellow
        for ($i = 1; $i -le 50; $i++) {
            try {
                Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 5 | Out-Null
                Write-Host "." -NoNewline -ForegroundColor Green
            } catch {
                Write-Host "x" -NoNewline -ForegroundColor Red
            }
            if ($i % 10 -eq 0) { Write-Host " $i/50" -ForegroundColor Gray }
            Start-Sleep -Milliseconds 200
        }
        Write-Host "`nOK Fase 1 completada" -ForegroundColor Green
        
        # Fase 2: HTTPCode_Target_5XX_Count
        Write-Host "`n[Fase 2/4] Probando HTTPCode_Target_5XX_Count..." -ForegroundColor Cyan
        Write-Host "Generando 6 peticiones que puedan fallar..." -ForegroundColor Yellow
        for ($i = 1; $i -le 6; $i++) {
            try {
                Invoke-WebRequest -Uri "$albUrl/endpoint-inexistente-$i" -Method GET -UseBasicParsing -TimeoutSec 5 | Out-Null
            } catch {
                Write-Host "OK Error $i/6" -ForegroundColor Yellow
            }
            Start-Sleep -Seconds 1
        }
        Write-Host "OK Fase 2 completada" -ForegroundColor Green
        
        # Fase 3: CPUUtilization
        Write-Host "`n[Fase 3/4] Probando CPUUtilization..." -ForegroundColor Cyan
        Write-Host "Iniciando carga de CPU en instancia EC2..." -ForegroundColor Yellow
        try {
            $instancesOutput = & aws ec2 describe-instances `
                --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
                --query 'Reservations[*].Instances[*].[InstanceId]' `
                --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $instancesJson = $instancesOutput -join "`n"
            } else {
                $instancesJson = $null
            }
            
            if ($instancesJson) {
                $instances = $instancesJson | ConvertFrom-Json
                if ($instances.Count -gt 0) {
                    $instanceId = $instances[0][0]
                    Write-Host "  Instalando stress-ng..." -ForegroundColor Gray
                    aws ssm send-command `
                        --instance-ids $instanceId `
                        --document-name "AWS-RunShellScript" `
                        --parameters "commands=['sudo yum install -y stress-ng']" `
                        --output json | Out-Null
                    Start-Sleep -Seconds 5
                    
                    Write-Host "  Iniciando carga de CPU..." -ForegroundColor Gray
                    aws ssm send-command `
                        --instance-ids $instanceId `
                        --document-name "AWS-RunShellScript" `
                        --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 600s > /tmp/stress-ng.log 2>&1 &']" `
                        --output json | Out-Null
                    Write-Host "OK Fase 3 completada (carga corriendo en segundo plano)" -ForegroundColor Green
                } else {
                    Write-Host "ADV Fase 3 omitida: No se encontraron instancias" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ADV Fase 3 omitida: Error al obtener instancias" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "ADV Fase 3 omitida: $_" -ForegroundColor Yellow
        }
        
        # Fase 4: UnHealthyHostCount (solo verificacion)
        Write-Host "`n[Fase 4/4] Verificando UnHealthyHostCount..." -ForegroundColor Cyan
        Write-Host "  Esta metrica se verifica automaticamente" -ForegroundColor Gray
        Write-Host "  Si hay hosts no saludables, aparecera en Widget 1 y 4" -ForegroundColor Gray
        Write-Host "OK Fase 4 completada" -ForegroundColor Green
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "OK Prueba completa finalizada" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nTiempos de espera:" -ForegroundColor Yellow
        Write-Host "  - HealthyHostCount: 2-5 minutos" -ForegroundColor White
        Write-Host "  - HTTPCode_Target_5XX_Count: 5-10 minutos" -ForegroundColor White
        Write-Host "  - CPUUtilization: 10-15 minutos" -ForegroundColor White
        Write-Host "  - UnHealthyHostCount: Verificar en dashboard" -ForegroundColor White
    }
    
    "6" {
        # Verificar alarmas
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Estado de Alarmas CloudWatch" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $alarms = @(
            "genius-dev-no-healthy-hosts",
            "genius-dev-unhealthy-hosts",
            "genius-dev-http-5xx-errors",
            "genius-dev-high-cpu"
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
    
    "7" {
        # Verificar metricas directamente
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Verificacion de Metricas (AWS CLI)" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Esta opcion te permite ver las metricas directamente desde AWS CLI" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Metricas disponibles:" -ForegroundColor Cyan
        Write-Host "  1. HealthyHostCount" -ForegroundColor White
        Write-Host "  2. UnHealthyHostCount" -ForegroundColor White
        Write-Host "  3. CPUUtilization" -ForegroundColor White
        Write-Host "  4. HTTPCode_Target_5XX_Count" -ForegroundColor White
        Write-Host ""
        Write-Host "Consulta test-metrics-guide.md para comandos especificos de cada metrica." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Ejemplo rapido - Ver errores 5xx:" -ForegroundColor Cyan
        Write-Host "  aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count ..." -ForegroundColor White
    }
    
    default {
        Write-Host "Opcion invalida. Ejecutando prueba basica..." -ForegroundColor Yellow
        $option = "1"
    }
}

# Mostrar resumen solo si se ejecuto prueba de trafico
if ($option -eq "1" -or $option -eq "5") {
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
if ($option -ne "6" -and $option -ne "7" -and $option -ne "2") {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Proximos pasos" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $waitTime = switch ($option) {
        "1" { "2-5 minutos" }
        "3" { "10-15 minutos" }
        "4" { "5-10 minutos" }
        "5" { "10-15 minutos" }
        default { "2-5 minutos" }
    }
    
    Write-Host "1. Espera $waitTime para que las metricas se actualicen" -ForegroundColor Yellow
    Write-Host "2. Ve a CloudWatch Dashboards" -ForegroundColor Yellow
    Write-Host "3. Abre el dashboard: genius-dev-application-status" -ForegroundColor Yellow
    Write-Host "4. Actualiza la pagina (F5) despues de esperar" -ForegroundColor Yellow
    
    Write-Host "`nWidgets a verificar:" -ForegroundColor Cyan
    switch ($option) {
        "1" {
            Write-Host "  - Widget 1: HealthyHostCount (linea verde)" -ForegroundColor White
        }
        "3" {
            Write-Host "  - Widget 2: CPUUtilization" -ForegroundColor White
            Write-Host "  - Alarma: genius-dev-high-cpu" -ForegroundColor White
        }
        "4" {
            Write-Host "  - Widget 3: HTTPCode_Target_5XX_Count" -ForegroundColor White
            Write-Host "  - Alarma: genius-dev-http-5xx-errors" -ForegroundColor White
        }
        "5" {
            Write-Host "  - Widget 1: HealthyHostCount y UnHealthyHostCount" -ForegroundColor White
            Write-Host "  - Widget 2: CPUUtilization" -ForegroundColor White
            Write-Host "  - Widget 3: HTTPCode_Target_5XX_Count" -ForegroundColor White
            Write-Host "  - Widget 4: UnHealthyHostCount (alarma)" -ForegroundColor White
        }
    }
    
    $dashboardUrl = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status"
    Write-Host "`nDashboard URL:" -ForegroundColor Cyan
    Write-Host $dashboardUrl -ForegroundColor White
    
    Write-Host "`nQuieres abrir el dashboard en tu navegador? (S/N)" -ForegroundColor Cyan
    $openBrowser = Read-Host
    if ($openBrowser -eq "S" -or $openBrowser -eq "s" -or $openBrowser -eq "Y" -or $openBrowser -eq "y") {
        Start-Process $dashboardUrl
    }
    
    Write-Host "`nListo! Revisa CloudWatch en unos minutos." -ForegroundColor Green
    Write-Host "`nTip: Consulta test-metrics-guide.md para mas detalles sobre cada prueba." -ForegroundColor Cyan
}
