# Problema: No Se Ven Cambios en la Metrica de CPU

## Problema

Ejecutaste la carga de CPU con `stress-ng` pero no ves cambios en el dashboard de CloudWatch.

## Causas Posibles

### 1. **Periodo de Actualizacion de Metricas** ⏱️

**Problema:**
Las metricas de CPU en CloudWatch se actualizan cada **5 minutos** (periodo de 300 segundos).

**Sintoma:**
- Ejecutaste la carga de CPU
- Esperas 1-2 minutos
- No ves cambios en el dashboard

**Solucion:**
- **Espera 5-10 minutos** antes de verificar el dashboard
- Las metricas apareceran en el siguiente periodo de 5 minutos

### 2. **La Metrica se Agrega por AutoScalingGroupName** 📊

**Problema:**
La metrica de CPU se agrega a nivel de **Auto Scaling Group**, no por instancia individual.

**Sintoma:**
- Solo cargaste CPU en 1 instancia
- Si hay multiples instancias, el promedio puede ser bajo

**Solucion:**
- Si tienes 2 instancias y solo cargas 1 al 100%, el promedio sera ~50%
- Para ver 100%, carga todas las instancias o reduce el ASG a 1 instancia

### 3. **stress-ng No Se Ejecuto Correctamente** ⚠️

**Problema:**
El comando SSM puede fallar silenciosamente o `stress-ng` puede no estar instalado.

**Sintoma:**
- El script dice "OK Carga de CPU iniciada"
- Pero `stress-ng` no esta corriendo en la instancia

**Solucion:**
- Ejecuta el script de verificacion: `.\verificar-cpu.ps1`
- Verifica manualmente en la instancia

### 4. **Periodo de Tiempo del Dashboard Muy Corto** 📅

**Problema:**
Si el dashboard muestra solo los ultimos 5 minutos, puede que la metrica aun no este disponible.

**Solucion:**
- Cambia el periodo de tiempo del dashboard a **1 hora** o **3 horas**
- Actualiza el dashboard (F5)

## Soluciones Paso a Paso

### Paso 1: Verificar que stress-ng Esta Corriendo

```powershell
cd C:\Users\jusef\OneDrive\Documentos\genius\infra
.\verificar-cpu.ps1
```

Este script verificara:
- Si `stress-ng` esta corriendo
- El uso de CPU actual en la instancia
- Las metricas en CloudWatch
- El estado de la alarma

### Paso 2: Verificar Metricas Directamente con AWS CLI

```powershell
cd envs\dev

# Obtener el nombre del ASG
$asgName = terraform output -raw autoscaling_group_name

# Ver metricas de los ultimos 30 minutos
$startTime = (Get-Date).AddMinutes(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
$endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")

aws cloudwatch get-metric-statistics `
    --namespace "AWS/EC2" `
    --metric-name "CPUUtilization" `
    --dimensions "Name=AutoScalingGroupName,Value=$asgName" `
    --start-time $startTime `
    --end-time $endTime `
    --period 300 `
    --statistics Average `
    --output table
```

### Paso 3: Verificar Manualmente en la Instancia

```powershell
# Obtener una instancia
$instanceId = (aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Verificar si stress-ng esta corriendo
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=['ps aux | grep stress-ng | grep -v grep']" `
    --output json

# Ver uso de CPU actual
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=['top -bn1 | head -5']" `
    --output json
```

### Paso 4: Reiniciar la Carga de CPU

Si `stress-ng` no esta corriendo, reinicia la carga:

```powershell
.\test-metrics.ps1
# Selecciona opcion 3
```

O manualmente:

```powershell
$instanceId = (aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Instalar stress-ng
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=['sudo yum install -y stress-ng']" `
    --output json

# Esperar 5 segundos
Start-Sleep -Seconds 5

# Iniciar carga de CPU
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 600s > /tmp/stress-ng.log 2>&1 &']" `
    --output json
```

## Configuracion de la Metrica de CPU

### Dashboard
- **Namespace**: `AWS/EC2`
- **Metric**: `CPUUtilization`
- **Dimension**: `AutoScalingGroupName` = nombre del ASG
- **Period**: 300 segundos (5 minutos)
- **Statistic**: Average

### Alarma
- **Nombre**: `genius-dev-high-cpu`
- **Umbral**: > 80%
- **Periodo**: 300 segundos (5 minutos)
- **Evaluaciones**: 2 (debe estar > 80% durante 10 minutos)

## Tiempos de Espera

| Accion | Tiempo de Espera |
|--------|------------------|
| Iniciar carga de CPU | Inmediato |
| Ver metrica en CloudWatch | 5-10 minutos |
| Ver cambios en dashboard | 5-10 minutos |
| Activar alarma | 10-15 minutos |

## Checklist de Verificacion

- [ ] Ejecute `.\verificar-cpu.ps1` para diagnosticar
- [ ] Verifique que `stress-ng` esta corriendo
- [ ] Verifique que el uso de CPU en la instancia es alto (> 80%)
- [ ] Verifique las metricas directamente con AWS CLI
- [ ] Espere 5-10 minutos antes de verificar el dashboard
- [ ] Cambie el periodo de tiempo del dashboard a 1h o 3h
- [ ] Verifique que el ASG tiene instancias activas
- [ ] Verifique que la dimension del dashboard coincide con el ASG

## Si Aun No Funciona

1. **Verifica que hay instancias en el ASG:**
   ```powershell
   $asgName = terraform output -raw autoscaling_group_name
   aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgName
   ```

2. **Verifica que la dimension es correcta:**
   ```powershell
   # Ver la configuracion del dashboard
   aws cloudwatch get-dashboard --dashboard-name "genius-dev-application-status" | ConvertFrom-Json | Select-Object -ExpandProperty DashboardBody | ConvertFrom-Json | Select-Object -ExpandProperty widgets | Where-Object { $_.properties.title -like "*CPU*" }
   ```

3. **Verifica que las metricas existen:**
   ```powershell
   $asgName = terraform output -raw autoscaling_group_name
   aws cloudwatch list-metrics --namespace "AWS/EC2" --metric-name "CPUUtilization" --dimensions "Name=AutoScalingGroupName,Value=$asgName"
   ```

## Notas Importantes

1. **La metrica se agrega por ASG**: Si tienes 2 instancias y solo cargas 1, el promedio sera ~50%

2. **El periodo es de 5 minutos**: Las metricas se actualizan cada 5 minutos, no en tiempo real

3. **La alarma requiere 10 minutos**: Debe estar > 80% durante 10 minutos (2 periodos de 5 minutos)

4. **El dashboard puede tardar**: Aunque las metricas existan, el dashboard puede tardar en actualizarse
