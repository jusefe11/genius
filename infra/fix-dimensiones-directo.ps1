# Fix directo del problema de dimensiones

Write-Host "Aplicando fix de dimensiones..." -ForegroundColor Cyan

$instances = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instances -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    foreach ($instanceId in $instanceIds) {
        $instId = $instanceId.Trim()
        Write-Host "`nInstancia: $instId" -ForegroundColor Yellow
        
        # Comando para corregir el script directamente
        $fixCommand = @'
sed -i 's|--dimensions InstanceId=$INSTANCE_ID,AutoScalingGroupName=$ASG_NAME|Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]"|g' /usr/local/bin/monitor-docker-containers.sh
sed -i 's|MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP|MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]"|g' /usr/local/bin/monitor-docker-containers.sh
sed -i 's|MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP|MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]"|g' /usr/local/bin/monitor-docker-containers.sh
/usr/local/bin/monitor-docker-containers.sh
'@
        
        $updateOutput = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=[$fixCommand]" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Comando enviado" -ForegroundColor Green
            Start-Sleep -Seconds 3
            
            # Verificar si funcionó
            $testOutput = & aws ssm send-command `
                --instance-ids $instId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh 2>&1 | tail -5']" `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Start-Sleep -Seconds 3
                $testResult = ($testOutput -join "`n") | ConvertFrom-Json
                $commandId = $testResult.Command.CommandId
                $testCheck = & aws ssm get-command-invocation --command-id $commandId --instance-id $instId --output json 2>&1 | ConvertFrom-Json
                Write-Host "  Salida: $($testCheck.StandardOutputContent)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ERROR" -ForegroundColor Red
        }
    }
    
    Write-Host "`nEspera 2-3 minutos y verifica el dashboard" -ForegroundColor Green
}
