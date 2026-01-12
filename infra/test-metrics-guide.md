# 🧪 Guía de Pruebas para Dashboard y Alarmas CloudWatch

Esta guía te ayuda a probar cada indicador y alarma del dashboard `genius-dev-application-status`.

---

## ⚙️ **CONFIGURACIÓN INICIAL**

Antes de ejecutar las pruebas, configura el DNS del ALB:

```bash
# DNS del ALB (ambiente dev)
export ALB_DNS="genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"

# O en PowerShell:
$env:ALB_DNS = "genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"
```

**Nota:** Todas las pruebas en esta guía usan la variable `$ALB_DNS` o `ALB_DNS` según el shell.

---

## 📊 **WIDGET 1: Health Checks - Hosts Saludables vs No Saludables**

### **Qué monitorea:**
- `HealthyHostCount`: Número de instancias saludables en el Target Group
- `UnHealthyHostCount`: Número de instancias no saludables en el Target Group

### **Alarma asociada:**
- **Nombre:** `genius-dev-unhealthy-hosts`
- **Umbral:** > 0 hosts no saludables
- **Periodo:** 60 segundos
- **Evaluaciones:** 1

### **Pruebas para verificar que funciona:**

#### ✅ **Prueba 1: Verificar hosts saludables (normal)**
```bash
# Asegúrate de tener configurado ALB_DNS (ver sección de configuración)

# 1. Hacer peticiones HTTP al ALB (debe responder 200 OK)
curl -I http://$ALB_DNS/

# 2. Generar múltiples peticiones para activar métricas
for i in {1..50}; do
  curl -s http://$ALB_DNS/ > /dev/null
  echo "Petición $i/50 completada"
  sleep 0.5
done

# 3. Esperar 2-3 minutos y verificar en CloudWatch Dashboard
# Deberías ver:
# - HealthyHostCount > 0 (línea verde)
# - UnHealthyHostCount = 0 (línea roja en 0)
```

#### ✅ **Prueba 2: Simular host no saludable (forzar alarma)**
```bash
# Opción A: Detener el servicio en una instancia
# 1. Conectarse a una instancia del ASG
ssh -i <key.pem> ec2-user@<instance-ip>

# 2. Detener el servicio de la aplicación
sudo systemctl stop <tu-servicio>
# O si es un contenedor:
sudo docker stop <container-id>

# 3. Esperar 1-2 minutos
# 4. Verificar en CloudWatch:
# - UnHealthyHostCount debería aumentar
# - La alarma debería activarse (estado ALARM)
# - Widget debería mostrar línea roja > 0

# Opción B: Bloquear el health check endpoint
# En la instancia, modificar el health check para que falle
# (depende de tu aplicación)
```

#### ✅ **Prueba 3: Verificar alarma en consola**
```bash
# Verificar estado de la alarma
aws cloudwatch describe-alarms \
  --alarm-names "genius-dev-unhealthy-hosts" \
  --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' \
  --output table

# Estados posibles:
# - OK: No hay hosts no saludables
# - ALARM: Hay hosts no saludables (alarma activa)
# - INSUFFICIENT_DATA: No hay datos suficientes
```

---

## 💻 **WIDGET 2: CPU Usage (%)**

### **Qué monitorea:**
- `CPUUtilization`: Porcentaje de uso de CPU promedio del Auto Scaling Group

### **Alarma asociada:**
- **Nombre:** `genius-dev-high-cpu`
- **Umbral:** > 80% de CPU
- **Periodo:** 300 segundos (5 minutos)
- **Evaluaciones:** 2 (debe estar > 80% durante 10 minutos)

### **Pruebas para verificar que funciona:**

#### ✅ **Prueba 1: Generar carga de CPU (forzar alarma)**
```bash
# 1. Conectarse a una instancia del ASG
ssh -i <key.pem> ec2-user@<instance-ip>

# 2. Generar carga de CPU al 100%
# Opción A: Usar stress-ng (instalar primero)
sudo yum install -y stress-ng
sudo stress-ng --cpu 4 --timeout 600s  # 4 cores al 100% por 10 minutos

# Opción B: Usar yes (más simple)
yes > /dev/null &  # Ejecutar varias veces para saturar CPU

# 3. Esperar 10-15 minutos (2 períodos de evaluación)
# 4. Verificar en CloudWatch:
# - CPU Usage debería subir a ~100%
# - La alarma debería activarse (estado ALARM)
# - Widget debería mostrar línea azul cerca de 100%

# 5. Detener la carga
pkill stress-ng
# O
pkill yes
```

#### ✅ **Prueba 2: Verificar métrica directamente**
```bash
# Ver métricas de CPU en los últimos 15 minutos
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=<ASG_NAME> \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --output table
```

#### ✅ **Prueba 3: Verificar alarma**
```bash
aws cloudwatch describe-alarms \
  --alarm-names "genius-dev-high-cpu" \
  --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' \
  --output table
```

---

## 🚨 **WIDGET 3: Errores HTTP 5xx**

### **Qué monitorea:**
- `HTTPCode_Target_5XX_Count`: Cantidad de errores 5xx del servidor

### **Alarma asociada:**
- **Nombre:** `genius-dev-http-5xx-errors`
- **Umbral:** > 5 errores en 5 minutos
- **Periodo:** 300 segundos (5 minutos)
- **Evaluaciones:** 1

### **Pruebas para verificar que funciona:**

#### ✅ **Prueba 1: Generar errores 5xx (forzar alarma)**
```bash
# Asegúrate de tener configurado ALB_DNS (ver sección de configuración)

# Opción A: Hacer peticiones a un endpoint que devuelva 500
# (si tu aplicación tiene un endpoint de prueba)
curl -X POST http://$ALB_DNS/api/test-error-500

# Opción B: Modificar temporalmente la aplicación para que falle
# En una instancia:
ssh -i <key.pem> ec2-user@<instance-ip>
# Modificar código para que devuelva 500 (ejemplo)
# O detener el servicio momentáneamente

# Opción C: Usar Apache Bench para generar muchas peticiones
# que fallen
ab -n 100 -c 10 http://$ALB_DNS/endpoint-que-no-existe

# 3. Esperar 5-10 minutos
# 4. Verificar en CloudWatch:
# - HTTPCode_Target_5XX_Count debería aumentar
# - La alarma debería activarse si > 5 errores
# - Widget debería mostrar línea naranja > 0
```

#### ✅ **Prueba 2: Verificar métrica directamente**
```bash
# Obtener el ARN del ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `genius-dev`)].LoadBalancerArn' \
  --output text)

# Ver métricas de errores 5xx
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=$ALB_ARN \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --output table
```

#### ✅ **Prueba 3: Verificar alarma**
```bash
aws cloudwatch describe-alarms \
  --alarm-names "genius-dev-http-5xx-errors" \
  --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' \
  --output table
```

---

## 📈 **WIDGET 4: Estado de Alarmas - Hosts No Saludables**

### **Qué monitorea:**
- `UnHealthyHostCount`: Mismo que Widget 1, pero enfocado en la alarma

### **Pruebas:**
- **Mismas que Widget 1** (Prueba 2: Simular host no saludable)

---

## 🔍 **VERIFICACIÓN GENERAL DEL DASHBOARD**

### **Checklist de verificación:**

```bash
# 1. Verificar que el dashboard existe
aws cloudwatch get-dashboard \
  --dashboard-name "genius-dev-application-status" \
  --output json | jq '.DashboardBody' | jq .

# 2. Verificar que todas las alarmas existen
aws cloudwatch describe-alarms \
  --alarm-name-prefix "genius-dev-" \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

# 3. Verificar que hay instancias en el ASG
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <ASG_NAME> \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances[*].InstanceId]' \
  --output table

# 4. Verificar que el Target Group tiene instancias registradas
TG_ARN=$(aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `genius-dev`)].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

---

## 🎯 **PRUEBA INTEGRAL: Simular Escenario Real**

### **Escenario: Aplicación bajo carga con errores**

```bash
# Asegúrate de tener configurado ALB_DNS (ver sección de configuración)

# 1. Generar tráfico normal (para ver hosts saludables)
for i in {1..100}; do
  curl -s http://$ALB_DNS/ > /dev/null
  sleep 0.1
done

# 2. Generar errores 5xx (6 errores para activar alarma)
for i in {1..6}; do
  curl -X POST http://$ALB_DNS/endpoint-inexistente
  sleep 1
done

# 3. Generar carga de CPU
ssh -i <key.pem> ec2-user@<instance-ip>
stress-ng --cpu 4 --timeout 600s &

# 4. Esperar 10-15 minutos

# 5. Verificar dashboard:
# - Widget 1: Debería mostrar hosts saludables
# - Widget 2: CPU debería estar alta
# - Widget 3: Errores 5xx deberían aparecer
# - Widget 4: Debería mostrar estado de alarma

# 6. Verificar todas las alarmas
aws cloudwatch describe-alarms \
  --alarm-name-prefix "genius-dev-" \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

---

## ⚠️ **TROUBLESHOOTING: "No hay datos disponibles"**

Si ves "No hay datos disponibles" en el dashboard:

### **Causas comunes:**

1. **No hay instancias en el ASG**
   ```bash
   # Verificar
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names <ASG_NAME> \
     --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
     --output table
   ```

2. **Target Group sin instancias registradas**
   ```bash
   # Verificar
   aws elbv2 describe-target-health --target-group-arn <TG_ARN>
   ```

3. **Dimensiones incorrectas en las métricas**
   - Verificar que `target_group_identifier` esté correcto
   - Verificar que `alb_name` esté correcto

4. **Periodo de tiempo muy corto**
   - Cambiar a 1h, 3h o 1d en el dashboard

5. **Métricas aún no disponibles (recién creado)**
   - CloudWatch puede tardar 2-5 minutos en mostrar datos
   - Esperar y refrescar el dashboard

---

## 📝 **NOTAS IMPORTANTES**

- ⏱️ **Tiempos de propagación:** Las métricas pueden tardar 2-5 minutos en aparecer
- 🔄 **Periodos de evaluación:** Las alarmas evalúan en períodos específicos (60s, 300s)
- 💰 **Costos:** Generar carga de CPU y errores puede generar costos adicionales
- 🧹 **Limpieza:** Después de las pruebas, detener procesos y restaurar servicios

---

## 🚀 **Script de Prueba Automatizado**

Puedes crear un script que ejecute todas estas pruebas. ¿Quieres que lo cree?
