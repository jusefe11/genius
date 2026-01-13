# Script para aplicar el fix de dimensiones en instancias existentes

Write-Host "Aplicando fix de dimensiones en CloudWatch..." -ForegroundColor Cyan

$instances = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instances -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    $fixScript = @'
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

# CORREGIDO: Las dimensiones van dentro de metric-data
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

echo "$(date): Running containers: $RUNNING_CONTAINERS, Total containers: $TOTAL_CONTAINERS, ASG: $ASG_NAME" >> /var/log/docker-monitor.log
'@
    
    foreach ($instanceId in $instanceIds) {
        $instId = $instanceId.Trim()
        Write-Host "`nActualizando instancia: $instId" -ForegroundColor Yellow
        
        # Guardar script en archivo temporal
        $tempFile = [System.IO.Path]::GetTempFileName()
        $fixScript | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
        
        # Leer y escapar para AWS SSM
        $scriptContent = Get-Content -Path $tempFile -Raw
        $scriptContent = $scriptContent -replace '`', '``' -replace '\$', '`$'
        
        $updateCmd = @"
cat > /tmp/monitor-fix.sh <<'FIXEOF'
$fixScript
FIXEOF
sudo mv /tmp/monitor-fix.sh /usr/local/bin/monitor-docker-containers.sh
sudo chmod +x /usr/local/bin/monitor-docker-containers.sh
sudo chown root:root /usr/local/bin/monitor-docker-containers.sh
/usr/local/bin/monitor-docker-containers.sh
"@
        
        $updateOutput = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=[$updateCmd]" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Script actualizado" -ForegroundColor Green
            Start-Sleep -Seconds 3
        } else {
            Write-Host "  ERROR Error al actualizar" -ForegroundColor Red
        }
        
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Fix aplicado. Espera 2-3 minutos y verifica el dashboard" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}
