# Resumen: Problema y Solución

## Problema Identificado

El dashboard de CloudWatch muestra **"No hay datos disponibles"** para Docker Containers porque:

1. **Error en el comando AWS CLI**: El script usa `--dimensions` como parámetro separado, pero cuando usas `--metric-data`, las dimensiones deben ir **DENTRO** del objeto `metric-data`.

2. **Error específico**: 
   ```
   The key "dimensions" cannot be specified when one of the following keys are also specified: metric_data
   ```

## Solución Aplicada

### 1. Script Corregido en `user_data.sh`

**ANTES (incorrecto):**
```bash
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP \
  --dimensions InstanceId=$INSTANCE_ID,AutoScalingGroupName=$ASG_NAME \
  --region "$AWS_REGION"
```

**DESPUÉS (correcto):**
```bash
aws cloudwatch put-metric-data \
  --namespace "Docker/Containers" \
  --metric-data MetricName=RunningContainers,Value=$RUNNING_CONTAINERS,Unit=Count,Timestamp=$TIMESTAMP,Dimensions="[{Name=InstanceId,Value=$INSTANCE_ID},{Name=AutoScalingGroupName,Value=$ASG_NAME}]" \
  --region "$AWS_REGION"
```

### 2. Para Aplicar en Instancias Existentes

**Opción A: Aplicar Terraform (recomendado)**
```bash
cd infra/envs/dev
terraform apply
```
Esto actualizará el `user_data.sh` para nuevas instancias.

**Opción B: Actualizar instancias existentes manualmente**

Necesitas reemplazar el script `/usr/local/bin/monitor-docker-containers.sh` en cada instancia con la versión corregida.

## Próximos Pasos

1. **Aplicar Terraform** para que nuevas instancias tengan el script correcto
2. **Actualizar instancias existentes** manualmente o recrearlas
3. **Esperar 2-3 minutos** después de aplicar el fix
4. **Verificar el dashboard** - deberías ver las métricas de Docker

## Verificación

Ejecuta:
```powershell
.\diagnostico-alarmas.ps1
```

Deberías ver métricas en la sección "2. METRICAS DE DOCKER" después de aplicar el fix.
