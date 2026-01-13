# Verificar errores del script de monitoreo Docker

Write-Host "Verificando errores del script de monitoreo..." -ForegroundColor Cyan

$instances = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instances -split "`n" | Where-Object { $_.Trim() -ne "" }
    $instanceId = $instanceIds[0].Trim()
    
    Write-Host "`nInstancia: $instanceId" -ForegroundColor Yellow
    
    # Verificar logs de errores
    Write-Host "`n1. Verificando logs de errores..." -ForegroundColor Yellow
    $errorLogCheck = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['cat /var/log/docker-monitor-errors.log 2>/dev/null || echo NO_ERROR_LOG']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $errorLogResult = ($errorLogCheck -join "`n") | ConvertFrom-Json
        $commandId = $errorLogResult.Command.CommandId
        $errorLogOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nLog de errores:" -ForegroundColor Cyan
        Write-Host $errorLogOutput.StandardOutputContent -ForegroundColor White
    }
    
    # Ejecutar script con salida detallada
    Write-Host "`n2. Ejecutando script con salida detallada..." -ForegroundColor Yellow
    $scriptRun = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['set -x; /usr/local/bin/monitor-docker-containers.sh 2>&1']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 5
        $scriptResult = ($scriptRun -join "`n") | ConvertFrom-Json
        $commandId = $scriptResult.Command.CommandId
        $scriptOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nSalida del script:" -ForegroundColor Cyan
        Write-Host $scriptOutput.StandardOutputContent -ForegroundColor White
        if ($scriptOutput.StandardErrorContent) {
            Write-Host "`nErrores:" -ForegroundColor Red
            Write-Host $scriptOutput.StandardErrorContent -ForegroundColor Red
        }
    }
    
    # Verificar permisos IAM
    Write-Host "`n3. Verificando permisos IAM..." -ForegroundColor Yellow
    $iamTest = & aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['aws autoscaling describe-auto-scaling-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) --query \"AutoScalingInstances[0].AutoScalingGroupName\" --output text 2>&1']" `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 3
        $iamResult = ($iamTest -join "`n") | ConvertFrom-Json
        $commandId = $iamResult.Command.CommandId
        $iamOutput = & aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId --output json 2>&1 | ConvertFrom-Json
        Write-Host "`nResultado de obtener ASG name:" -ForegroundColor Cyan
        Write-Host $iamOutput.StandardOutputContent -ForegroundColor White
        if ($iamOutput.StandardErrorContent) {
            Write-Host "`nError:" -ForegroundColor Red
            Write-Host $iamOutput.StandardErrorContent -ForegroundColor Red
        }
    }
}
