# Script para verificar logs del script de monitoreo Docker

Write-Host "Verificando logs del script de monitoreo Docker..." -ForegroundColor Cyan

$instances = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instances -split "`n" | Where-Object { $_.Trim() -ne "" }
    $instanceId = $instanceIds[0].Trim()
    
    Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Yellow
    
    # Verificar logs
    Write-Host "`nVerificando log del script..." -ForegroundColor Yellow
    $logCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['tail -n 20 /var/log/docker-monitor.log 2>/dev/null || echo LOG_FILE_NOT_FOUND']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $logResult = ($logCheck -join "`n") | ConvertFrom-Json
        $commandId = $logResult.Command.CommandId
        $logOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nLogs:" -ForegroundColor Cyan
        Write-Host $logOutput.StandardOutputContent -ForegroundColor White
    }
    
    # Ejecutar script con salida completa
    Write-Host "`nEjecutando script con salida completa..." -ForegroundColor Yellow
    $scriptRun = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['bash -x /usr/local/bin/monitor-docker-containers.sh 2>&1']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 5
        $scriptResult = ($scriptRun -join "`n") | ConvertFrom-Json
        $commandId = $scriptResult.Command.CommandId
        $scriptOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nSalida del script (con debug):" -ForegroundColor Cyan
        Write-Host $scriptOutput.StandardOutputContent -ForegroundColor White
        if ($scriptOutput.StandardErrorContent) {
            Write-Host "`nErrores:" -ForegroundColor Red
            Write-Host $scriptOutput.StandardErrorContent -ForegroundColor Red
        }
    }
    
    # Verificar permisos IAM
    Write-Host "`nVerificando permisos IAM..." -ForegroundColor Yellow
    $iamCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['aws sts get-caller-identity 2>&1']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $iamResult = ($iamCheck -join "`n") | ConvertFrom-Json
        $commandId = $iamResult.Command.CommandId
        $iamOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nIdentidad IAM:" -ForegroundColor Cyan
        Write-Host $iamOutput.StandardOutputContent -ForegroundColor White
        if ($iamOutput.StandardErrorContent) {
            Write-Host "`nErrores IAM:" -ForegroundColor Red
            Write-Host $iamOutput.StandardErrorContent -ForegroundColor Red
        }
    }
}
