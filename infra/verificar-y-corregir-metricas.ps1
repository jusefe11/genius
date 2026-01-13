# Script para verificar y corregir el envio de metricas Docker
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verificando y Corrigiendo Metricas Docker" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Obtener instancias
$instances = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instances -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    Write-Host "Instancias encontradas: $($instanceIds.Count)" -ForegroundColor Green
    
    foreach ($instanceId in $instanceIds) {
        $instId = $instanceId.Trim()
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Instancia: $instId" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        
        # 1. Verificar si el script existe y es ejecutable
        Write-Host "`n1. Verificando script de monitoreo..." -ForegroundColor Yellow
        $checkScript = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['test -x /usr/local/bin/monitor-docker-containers.sh && echo EXISTS || echo NOT_FOUND']" `
            --output json 2>&1
        
        Start-Sleep -Seconds 2
        if ($LASTEXITCODE -eq 0) {
            $checkResult = ($checkScript -join "`n") | ConvertFrom-Json
            $commandId = $checkResult.Command.CommandId
            $checkOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
            Write-Host "   Resultado: $($checkOutput.StandardOutputContent.Trim())" -ForegroundColor $(if ($checkOutput.StandardOutputContent -like "*EXISTS*") { "Green" } else { "Red" })
        }
        
        # 2. Verificar contenedores Docker
        Write-Host "`n2. Verificando contenedores Docker..." -ForegroundColor Yellow
        $checkDocker = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['DOCKER_CMD=\"docker\"; if ! docker ps >/dev/null 2>&1; then DOCKER_CMD=\"sudo docker\"; fi; echo \"Contenedores corriendo:\"; $DOCKER_CMD ps -q | wc -l']" `
            --output json 2>&1
        
        Start-Sleep -Seconds 2
        if ($LASTEXITCODE -eq 0) {
            $dockerResult = ($checkDocker -join "`n") | ConvertFrom-Json
            $commandId = $dockerResult.Command.CommandId
            $dockerOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
            Write-Host "   $($dockerOutput.StandardOutputContent.Trim())" -ForegroundColor White
        }
        
        # 3. Ejecutar script manualmente y ver errores
        Write-Host "`n3. Ejecutando script de monitoreo..." -ForegroundColor Yellow
        $runScript = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh 2>&1']" `
            --output json 2>&1
        
        Start-Sleep -Seconds 3
        if ($LASTEXITCODE -eq 0) {
            $runResult = ($runScript -join "`n") | ConvertFrom-Json
            $commandId = $runResult.Command.CommandId
            $runOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
            
            if ($runOutput.StandardOutputContent) {
                Write-Host "   Salida:" -ForegroundColor White
                $runOutput.StandardOutputContent -split "`n" | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
            }
            
            if ($runOutput.StandardErrorContent) {
                Write-Host "   Errores:" -ForegroundColor Red
                $runOutput.StandardErrorContent -split "`n" | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
            }
        }
        
        # 4. Verificar logs de errores
        Write-Host "`n4. Verificando logs de errores..." -ForegroundColor Yellow
        $checkLogs = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['tail -n 10 /var/log/docker-monitor-errors.log 2>/dev/null || echo NO_ERROR_LOG']" `
            --output json 2>&1
        
        Start-Sleep -Seconds 2
        if ($LASTEXITCODE -eq 0) {
            $logsResult = ($checkLogs -join "`n") | ConvertFrom-Json
            $commandId = $logsResult.Command.CommandId
            $logsOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
            if ($logsOutput.StandardOutputContent -notlike "*NO_ERROR_LOG*") {
                Write-Host "   Errores encontrados:" -ForegroundColor Red
                $logsOutput.StandardOutputContent -split "`n" | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
            } else {
                Write-Host "   No hay log de errores (puede ser bueno o malo)" -ForegroundColor Yellow
            }
        }
        
        # 5. Verificar permisos IAM
        Write-Host "`n5. Verificando permisos IAM..." -ForegroundColor Yellow
        $checkIAM = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=['aws autoscaling describe-auto-scaling-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) --query \"AutoScalingInstances[0].AutoScalingGroupName\" --output text 2>&1']" `
            --output json 2>&1
        
        Start-Sleep -Seconds 2
        if ($LASTEXITCODE -eq 0) {
            $iamResult = ($checkIAM -join "`n") | ConvertFrom-Json
            $commandId = $iamResult.Command.CommandId
            $iamOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
            $asgName = $iamOutput.StandardOutputContent.Trim()
            if ($asgName -and $asgName -ne "unknown" -and $asgName -notlike "*error*" -and $asgName -notlike "*denied*") {
                Write-Host "   ASG Name obtenido: $asgName" -ForegroundColor Green
            } else {
                Write-Host "   ERROR: No se pudo obtener ASG Name" -ForegroundColor Red
                Write-Host "   Salida: $asgName" -ForegroundColor Gray
                Write-Host "   Esto indica problema de permisos IAM" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RECOMENDACIONES:" -ForegroundColor Yellow
    Write-Host "1. Si el ASG Name no se obtiene: Aplica terraform apply para actualizar permisos IAM" -ForegroundColor White
    Write-Host "2. Si hay errores en los logs: Revisa los permisos de CloudWatch PutMetricData" -ForegroundColor White
    Write-Host "3. Espera 2-3 minutos y verifica el dashboard nuevamente" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: No se pudieron obtener instancias" -ForegroundColor Red
}
