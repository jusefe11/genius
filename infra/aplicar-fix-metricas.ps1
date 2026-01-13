# Script para aplicar el fix de metricas en instancias existentes
# Este script actualiza el script de monitoreo y los permisos IAM

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Aplicando Fix de Metricas Docker" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Obtener instancias
Write-Host "Obteniendo instancias EC2..." -ForegroundColor Yellow
$instancesOutput = & aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[*].Instances[*].[InstanceId]' `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    $instanceIds = $instancesOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    Write-Host "OK Instancias encontradas: $($instanceIds.Count)" -ForegroundColor Green
    $instanceIds | ForEach-Object { Write-Host "  - $($_.Trim())" -ForegroundColor White }
    
    # Script actualizado para monitoreo
    $monitorScript = @'
#!/bin/bash
# Script para monitorear contenedores Docker y enviar metricas a CloudWatch

# Obtener region de AWS
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

# Intentar usar docker sin sudo primero, luego con sudo si falla
DOCKER_CMD="docker"
if ! $DOCKER_CMD ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

# Contar contenedores Docker corriendo
RUNNING_CONTAINERS=$($DOCKER_CMD ps -q 2>/dev/null | wc -l)

# Contar todos los contenedores (corriendo y detenidos)
TOTAL_CONTAINERS=$($DOCKER_CMD ps -aq 2>/dev/null | wc -l)

# Obtener nombre del Auto Scaling Group desde metadata
# Intentar varias veces con retry
ASG_NAME="unknown"
for i in {1..3}; do
    ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
      --instance-ids "$INSTANCE_ID" \
      --region "$AWS_REGION" \
      --query 'AutoScalingInstances[0].AutoScalingGroupName' \
      --output text 2>/dev/null)
    if [ "$ASG_NAME" != "None" ] && [ -n "$ASG_NAME" ] && [ "$ASG_NAME" != "unknown" ]; then
        break
    fi
    sleep 1
done

# Si aun no tenemos el ASG name, intentar obtenerlo de tags de la instancia
if [ "$ASG_NAME" == "unknown" ] || [ "$ASG_NAME" == "None" ] || [ -z "$ASG_NAME" ]; then
    ASG_NAME=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --region "$AWS_REGION" \
      --query 'Reservations[0].Instances[0].Tags[?Key==`aws:autoscaling:groupName`].Value' \
      --output text 2>/dev/null)
fi

# Si aun no tenemos el ASG name, usar un valor por defecto basado en el nombre del proyecto
if [ "$ASG_NAME" == "unknown" ] || [ "$ASG_NAME" == "None" ] || [ -z "$ASG_NAME" ]; then
    ASG_NAME="genius-dev-asg"
fi

# Enviar metricas a CloudWatch con logging de errores
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S)
ERROR_LOG="/var/log/docker-monitor-errors.log"

# Enviar RunningContainers
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP \
  --dimensions InstanceId=$INSTANCE_ID,AutoScalingGroupName=$ASG_NAME \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

# Enviar TotalContainers
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP \
  --dimensions InstanceId=$INSTANCE_ID,AutoScalingGroupName=$ASG_NAME \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

# Log para debugging
echo "$(date): Running containers: $RUNNING_CONTAINERS, Total containers: $TOTAL_CONTAINERS, ASG: $ASG_NAME" >> /var/log/docker-monitor.log
'@
    
    # Actualizar script en cada instancia
    foreach ($instanceId in $instanceIds) {
        $instId = $instanceId.Trim()
        Write-Host "`nActualizando script en instancia: $instId" -ForegroundColor Yellow
        
        # Guardar script en archivo temporal local
        $tempScript = [System.IO.Path]::GetTempFileName()
        $monitorScript | Out-File -FilePath $tempScript -Encoding UTF8 -NoNewline
        
        # Leer y escapar el contenido para AWS SSM
        $scriptContent = Get-Content -Path $tempScript -Raw
        $scriptContentEscaped = $scriptContent -replace '"', '\"' -replace '`', '\`' -replace '\$', '\$'
        
        # Crear comando para actualizar el script
        $updateCommands = @(
            "cat > /tmp/monitor-docker-containers-new.sh <<'SCRIPTEOF'",
            $scriptContent,
            "SCRIPTEOF",
            "sudo mv /tmp/monitor-docker-containers-new.sh /usr/local/bin/monitor-docker-containers.sh",
            "sudo chmod +x /usr/local/bin/monitor-docker-containers.sh",
            "sudo chown root:root /usr/local/bin/monitor-docker-containers.sh"
        )
        
        $commandsJson = ($updateCommands | ConvertTo-Json -Compress) -replace '"', '\"'
        
        $updateOutput = & aws ssm send-command `
            --instance-ids $instId `
            --document-name "AWS-RunShellScript" `
            --parameters "commands=$commandsJson" `
            --output json 2>&1
        
        # Limpiar archivo temporal
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Script actualizado" -ForegroundColor Green
            
            # Ejecutar el script inmediatamente para enviar metricas
            Write-Host "  Ejecutando script para enviar metricas..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
            
            $runOutput = & aws ssm send-command `
                --instance-ids $instId `
                --document-name "AWS-RunShellScript" `
                --parameters "commands=['/usr/local/bin/monitor-docker-containers.sh']" `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  OK Script ejecutado" -ForegroundColor Green
            }
        } else {
            Write-Host "  ERROR Error al actualizar script" -ForegroundColor Red
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "1. Aplica los cambios de Terraform para actualizar permisos IAM:" -ForegroundColor White
    Write-Host "   cd envs/dev" -ForegroundColor Gray
    Write-Host "   terraform apply" -ForegroundColor Gray
    Write-Host "`n2. Espera 2-3 minutos para que las metricas aparezcan en CloudWatch" -ForegroundColor White
    Write-Host "`n3. Verifica el dashboard:" -ForegroundColor White
    Write-Host "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "ERROR Error al obtener instancias" -ForegroundColor Red
}
