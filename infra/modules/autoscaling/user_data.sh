#!/bin/bash
# User data script para instancias EC2 en el Auto Scaling Group

# Log file para debugging
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=========================================" >> $LOG_FILE
echo "Iniciando user-data script" >> $LOG_FILE
echo "Fecha: $(date)" >> $LOG_FILE
echo "=========================================" >> $LOG_FILE

# Actualizar sistema
yum update -y

# Instalar AWS CLI v2 si no está instalado (requerido para Secrets Manager)
if ! command -v aws &> /dev/null; then
    echo "Instalando AWS CLI v2..." >> $LOG_FILE
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Asegurar que SSM Agent esté instalado y ejecutándose (requerido para Session Manager)
# Amazon Linux 2 viene con SSM Agent preinstalado, pero lo verificamos y habilitamos
if ! command -v amazon-ssm-agent &> /dev/null; then
    yum install -y amazon-ssm-agent
fi

# Iniciar y habilitar SSM Agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Verificar estado del SSM Agent
systemctl status amazon-ssm-agent || echo "SSM Agent status check failed" >> $LOG_FILE

# Función para leer secretos de AWS Secrets Manager
read_secret() {
    local secret_name=$1
    local output_file=$2
    
    echo "Obteniendo secreto: $secret_name" >> $LOG_FILE
    aws secretsmanager get-secret-value --secret-id "$secret_name" --region "$AWS_REGION" --query SecretString --output text > "$output_file" 2>>$LOG_FILE
    
    if [ $? -eq 0 ]; then
        echo "Secreto $secret_name obtenido exitosamente" >> $LOG_FILE
        # Establecer permisos de solo lectura
        chmod 600 "$output_file"
        return 0
    else
        echo "ERROR: No se pudo obtener el secreto $secret_name" >> $LOG_FILE
        return 1
    fi
}

# Crear directorio para almacenar secretos
SECRETS_DIR="/opt/app/secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Leer secretos de Secrets Manager si están configurados
if [ -n "${secrets_manager_secrets}" ]; then
    echo "Leyendo secretos de AWS Secrets Manager..." >> $LOG_FILE
    
    # Obtener región de AWS
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
    export AWS_DEFAULT_REGION=$AWS_REGION
    
    # Leer cada secreto y guardarlo en un archivo JSON
    for secret_name in ${secrets_manager_secrets}; do
        # Normalizar nombre del archivo (reemplazar / por -)
        secret_file=$(echo "$secret_name" | sed 's/\//-/g')
        output_file="$SECRETS_DIR/$${secret_file}.json"
        
        if read_secret "$secret_name" "$output_file"; then
            # Si es el secreto de base de datos, extraer variables de entorno
            if [[ "$secret_name" == *"/database/credentials"* ]]; then
                echo "Extrayendo credenciales de base de datos..." >> $LOG_FILE
                # Parsear JSON y crear archivo de variables de entorno
                cat > "$SECRETS_DIR/db.env" <<EOF
$(cat "$output_file" | jq -r 'to_entries[] | "\(.key | ascii_upcase)=\(.value)"')
EOF
                chmod 600 "$SECRETS_DIR/db.env"
                echo "Credenciales de BD guardadas en $SECRETS_DIR/db.env" >> $LOG_FILE
            fi
            
            # Si es el secreto de API Keys, extraer variables de entorno
            if [[ "$secret_name" == *"/app/api-keys"* ]]; then
                echo "Extrayendo API Keys..." >> $LOG_FILE
                cat > "$SECRETS_DIR/api-keys.env" <<EOF
$(cat "$output_file" | jq -r 'to_entries[] | "\(.key | ascii_upcase)=\(.value)"')
EOF
                chmod 600 "$SECRETS_DIR/api-keys.env"
                echo "API Keys guardadas en $SECRETS_DIR/api-keys.env" >> $LOG_FILE
            fi
        fi
    done
    
    echo "Secretos procesados. Archivos disponibles en $SECRETS_DIR" >> $LOG_FILE
else
    echo "No hay secretos configurados para leer" >> $LOG_FILE
fi

# Instalar jq para parsear JSON (usado para procesar secretos)
yum install -y jq

# Instalar CloudWatch Agent para metricas de RAM
echo "Instalando CloudWatch Agent..." >> $LOG_FILE
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm -O /tmp/amazon-cloudwatch-agent.rpm 2>>$LOG_FILE
if [ $? -eq 0 ]; then
    rpm -U /tmp/amazon-cloudwatch-agent.rpm 2>>$LOG_FILE
    
    # Crear configuracion para metricas de RAM y CPU
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENTEOF'
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": false
      }
    }
  }
}
CWAGENTEOF
    
    # Iniciar CloudWatch Agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s 2>>$LOG_FILE
    
    # Habilitar CloudWatch Agent para que inicie automaticamente
    systemctl enable amazon-cloudwatch-agent 2>>$LOG_FILE
    
    echo "CloudWatch Agent instalado y configurado" >> $LOG_FILE
else
    echo "ADVERTENCIA: No se pudo instalar CloudWatch Agent" >> $LOG_FILE
fi

# Instalar herramientas básicas
yum install -y docker

# Iniciar Docker
systemctl start docker
systemctl enable docker

# Crear un contenedor simple de prueba que escuche en el puerto de la aplicación
# NOTA: Esto es solo un placeholder. En producción, reemplazar con tu aplicación real
# Los secretos están disponibles en $SECRETS_DIR para que tu aplicación los use

# Ejemplo: Si existe db.env, cargar variables de entorno antes de iniciar la app
ENV_FILE_ARGS=""
if [ -f "$SECRETS_DIR/db.env" ]; then
    ENV_FILE_ARGS="$ENV_FILE_ARGS --env-file $SECRETS_DIR/db.env"
fi
if [ -f "$SECRETS_DIR/api-keys.env" ]; then
    ENV_FILE_ARGS="$ENV_FILE_ARGS --env-file $SECRETS_DIR/api-keys.env"
fi

docker run -d \
  --name app \
  --restart always \
  -p ${app_port}:8080 \
  -e PORT=8080 \
  $ENV_FILE_ARGS \
  nginx:alpine

# Health check básico (opcional)
# El health check del ALB verificará que el puerto responda
# En producción, configurar un health endpoint apropiado

# Crear script para monitorear contenedores Docker y enviar metricas a CloudWatch
echo "Configurando monitoreo de contenedores Docker..." >> $LOG_FILE
cat > /usr/local/bin/monitor-docker-containers.sh <<'DOCKERMONEOF'
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

# Enviar RunningContainers (las dimensiones deben ir dentro de metric-data)
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

# Enviar TotalContainers
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=TotalContainers,Value=$TOTAL_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" \
  --region "$AWS_REGION" >> $ERROR_LOG 2>&1

# Log para debugging
echo "$(date): Running containers: $RUNNING_CONTAINERS, Total containers: $TOTAL_CONTAINERS, ASG: $ASG_NAME" >> /var/log/docker-monitor.log
DOCKERMONEOF

chmod +x /usr/local/bin/monitor-docker-containers.sh

# Crear cron job para ejecutar el script cada minuto
echo "*/1 * * * * root /usr/local/bin/monitor-docker-containers.sh" >> /etc/crontab

# Ejecutar el script inmediatamente
/usr/local/bin/monitor-docker-containers.sh

echo "Monitoreo de contenedores Docker configurado" >> $LOG_FILE

echo "Aplicación iniciada en el puerto ${app_port}" >> $LOG_FILE
echo "SSM Agent configurado para Session Manager" >> $LOG_FILE
if [ -d "$SECRETS_DIR" ]; then
    echo "Secretos disponibles en: $SECRETS_DIR" >> $LOG_FILE
fi
echo "=========================================" >> $LOG_FILE
echo "user-data script completado" >> $LOG_FILE
echo "=========================================" >> $LOG_FILE
