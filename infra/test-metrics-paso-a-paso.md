# 🧪 Guía Paso a Paso: Pruebas de Métricas CloudWatch

Esta guía te explica **DÓNDE** y **CÓMO** ejecutar cada prueba para verificar que los indicadores del dashboard funcionan.

---

## 📋 **INFORMACIÓN IMPORTANTE**

**DNS del ALB (dev):**
```
genius-dev-alb-315902661.us-east-1.elb.amazonaws.com
```

**Dashboard de CloudWatch:**
```
genius-dev-application-status
```

---

## 🖥️ **DÓNDE EJECUTAR LAS PRUEBAS**

**TODAS las pruebas se ejecutan desde PowerShell en tu computadora Windows.**

- ✅ **PowerShell:** Todas las pruebas usan PowerShell
- ✅ **AWS CLI:** Para comandos de AWS (debe estar instalado y configurado)
- ✅ **Script automatizado:** `test-metrics.ps1` para pruebas rápidas

---

## 🎯 **PRUEBA 1: Health Checks (Widget 1)**

### **Objetivo:** Verificar que el dashboard muestra hosts saludables

### **Dónde ejecutar:** Desde PowerShell en tu computadora

### **Paso a paso:**

#### **Opción A: Usar el script de PowerShell (MÁS FÁCIL)**

1. **Abre PowerShell** en tu computadora
2. **Navega a la carpeta infra:**
   ```powershell
   cd C:\Users\jusef\OneDrive\Documentos\genius\infra
   ```
3. **Ejecuta el script:**
   ```powershell
   .\test-metrics.ps1
   ```
4. **Selecciona opción 1** (Prueba básica)
5. **Ingresa 50** cuando te pregunte cuántas peticiones
6. **Espera 2-5 minutos**
7. **Abre CloudWatch Dashboard:**
   - Ve a: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status
   - O busca "Dashboards" en CloudWatch y abre "genius-dev-application-status"
8. **Verifica Widget 1:**
   - Deberías ver una línea verde (HealthyHostCount) > 0
   - Deberías ver una línea roja (UnHealthyHostCount) = 0

#### **Opción B: Usar PowerShell manualmente**

1. **Abre PowerShell** en tu computadora
2. **Ejecuta estos comandos uno por uno:**
   ```powershell
   # Configurar el DNS del ALB
   $ALB_DNS = "genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"
   
   # Hacer una petición de prueba
   Invoke-WebRequest -Uri "http://$ALB_DNS/" -Method GET -UseBasicParsing
   
   # Generar 50 peticiones
   for ($i = 1; $i -le 50; $i++) {
       try {
           Invoke-WebRequest -Uri "http://$ALB_DNS/" -Method GET -UseBasicParsing -TimeoutSec 5 | Out-Null
           Write-Host "Petición $i/50 completada" -ForegroundColor Green
       } catch {
           Write-Host "Error en petición $i" -ForegroundColor Red
       }
       Start-Sleep -Milliseconds 500
   }
   ```
3. **Espera 2-5 minutos**
4. **Abre CloudWatch Dashboard** y verifica Widget 1

#### **Opción C: Usar curl (si lo tienes instalado)**

1. **Abre PowerShell o CMD** en tu computadora
2. **Ejecuta:**
   ```bash
   # Configurar DNS
   $env:ALB_DNS = "genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"
   
   # Hacer peticiones (si tienes curl instalado)
   for ($i = 1; $i -le 50; $i++) {
       curl.exe -s http://$env:ALB_DNS/ > $null
       Write-Host "Petición $i/50"
       Start-Sleep -Milliseconds 500
   }
   ```
3. **Espera 2-5 minutos**
4. **Abre CloudWatch Dashboard** y verifica Widget 1

---

## 🚨 **PRUEBA 2: Errores HTTP 5xx (Widget 3)**

### **Objetivo:** Verificar que el dashboard detecta errores 5xx y activa la alarma

### **Dónde ejecutar:** Desde PowerShell en tu computadora

### **Paso a paso:**

#### **Opción A: Usar el script de PowerShell**

1. **Abre PowerShell** en tu computadora
2. **Navega a la carpeta infra:**
   ```powershell
   cd C:\Users\jusef\OneDrive\Documentos\genius\infra
   ```
3. **Ejecuta el script:**
   ```powershell
   .\test-metrics.ps1
   ```
4. **Selecciona opción 2** (Prueba de errores)
5. **Espera 5-10 minutos**
6. **Abre CloudWatch Dashboard** y verifica:
   - Widget 3: Debería mostrar errores 5xx (línea naranja)
   - Alarma: `genius-dev-http-5xx-errors` debería estar en estado ALARM

#### **Opción B: Manualmente (si tu app genera 5xx)**

1. **Abre PowerShell** en tu computadora
2. **Ejecuta:**
   ```powershell
   $ALB_DNS = "genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"
   
   # Generar 6 peticiones que fallen (para activar alarma)
   for ($i = 1; $i -le 6; $i++) {
       try {
           # Intentar acceder a endpoint que no existe
           Invoke-WebRequest -Uri "http://$ALB_DNS/endpoint-inexistente-$i" -Method GET -UseBasicParsing -TimeoutSec 5
       } catch {
           Write-Host "Error $i/6 generado" -ForegroundColor Yellow
       }
       Start-Sleep -Seconds 1
   }
   ```
3. **Nota importante:** Si tu aplicación no genera errores 5xx automáticamente, necesitarás:
   - Modificar temporalmente tu código para que devuelva 500
   - O detener un servicio en una instancia EC2

#### **Opción C: Desde una instancia EC2 (si necesitas modificar la app)**

1. **Conéctate a una instancia EC2:**
   ```powershell
   # Obtener la IP de una instancia
   # (Necesitas el archivo .pem de tu key)
   ssh -i C:\ruta\a\tu-key.pem ec2-user@<IP-INSTANCIA>
   ```
2. **Detener el servicio temporalmente:**
   ```bash
   # Si es un servicio systemd
   sudo systemctl stop <nombre-servicio>
   
   # O si es un contenedor Docker
   sudo docker stop <container-id>
   ```
3. **Generar tráfico desde tu computadora:**
   ```powershell
   $ALB_DNS = "genius-dev-alb-315902661.us-east-1.elb.amazonaws.com"
   for ($i = 1; $i -le 10; $i++) {
       Invoke-WebRequest -Uri "http://$ALB_DNS/" -Method GET -UseBasicParsing
       Start-Sleep -Seconds 1
   }
   ```
4. **Espera 5-10 minutos**
5. **Verifica en CloudWatch:**
   - Widget 3 debería mostrar errores
   - La alarma debería activarse
6. **Restaurar el servicio:**
   ```bash
   # Volver a la instancia y restaurar
   sudo systemctl start <nombre-servicio>
   # O
   sudo docker start <container-id>
   ```

---

## 💻 **PRUEBA 3: CPU Usage (Widget 2)**

### **Objetivo:** Verificar que el dashboard muestra uso de CPU y activa la alarma

### **Dónde ejecutar:** Desde PowerShell en tu computadora

### **Paso a paso:**

#### **Opción A: Usar AWS Systems Manager (SSM) - RECOMENDADO**

1. **Abre PowerShell** en tu computadora

2. **Obtener el Instance ID de una instancia EC2:**
   ```powershell
   # Obtener instancias del ASG
   $instances = aws ec2 describe-instances `
     --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
     --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
     --output json | ConvertFrom-Json
   
   # Mostrar instancias disponibles
   Write-Host "Instancias disponibles:" -ForegroundColor Cyan
   $instances | ForEach-Object { Write-Host "  Instance ID: $($_[0]) - IP: $($_[1])" }
   
   # Seleccionar la primera instancia
   $instanceId = $instances[0][0]
   Write-Host "`nUsando instancia: $instanceId" -ForegroundColor Green
   ```

3. **Instalar stress-ng en la instancia (si no está instalado):**
   ```powershell
   Write-Host "Instalando stress-ng..." -ForegroundColor Yellow
   aws ssm send-command `
     --instance-ids $instanceId `
     --document-name "AWS-RunShellScript" `
     --parameters "commands=['sudo yum install -y stress-ng']" `
     --output json | Out-Null
   
   Start-Sleep -Seconds 5
   Write-Host "✓ stress-ng instalado" -ForegroundColor Green
   ```

4. **Generar carga de CPU en la instancia:**
   ```powershell
   Write-Host "`nGenerando carga de CPU al 100% por 10 minutos..." -ForegroundColor Yellow
   Write-Host "Esto se ejecutará en segundo plano en la instancia." -ForegroundColor Cyan
   
   # Ejecutar stress-ng en segundo plano
   aws ssm send-command `
     --instance-ids $instanceId `
     --document-name "AWS-RunShellScript" `
     --parameters "commands=['nohup sudo stress-ng --cpu 4 --timeout 600s > /tmp/stress-ng.log 2>&1 &']" `
     --output json | Out-Null
   
   Write-Host "✓ Carga de CPU iniciada" -ForegroundColor Green
   Write-Host "`nEspera 10-15 minutos para que la alarma se active..." -ForegroundColor Yellow
   ```

5. **Verificar que está corriendo:**
   ```powershell
   # Verificar proceso
   $result = aws ssm send-command `
     --instance-ids $instanceId `
     --document-name "AWS-RunShellScript" `
     --parameters "commands=['ps aux | grep stress-ng']" `
     --output json | ConvertFrom-Json
   
   $commandId = $result.Command.CommandId
   Start-Sleep -Seconds 3
   
   $output = aws ssm get-command-invocation `
     --command-id $commandId `
     --instance-id $instanceId `
     --query 'StandardOutputContent' `
     --output text
   
   Write-Host "Estado del proceso:" -ForegroundColor Cyan
   Write-Host $output
   ```

6. **Esperar 10-15 minutos**

7. **Abrir CloudWatch Dashboard:**
   - Ve a: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status
   - Verifica Widget 2: Debería mostrar CPU cerca de 100%

8. **Verificar la alarma:**
   ```powershell
   aws cloudwatch describe-alarms `
     --alarm-names "genius-dev-high-cpu" `
     --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' `
     --output table
   ```

9. **Detener la carga de CPU:**
   ```powershell
   Write-Host "`nDeteniendo carga de CPU..." -ForegroundColor Yellow
   aws ssm send-command `
     --instance-ids $instanceId `
     --document-name "AWS-RunShellScript" `
     --parameters "commands=['sudo pkill stress-ng']" `
     --output json | Out-Null
   
   Write-Host "✓ Carga de CPU detenida" -ForegroundColor Green
   ```

#### **Opción B: Usar SSH desde PowerShell (si SSM no está disponible)**

1. **Abre PowerShell** en tu computadora

2. **Obtener la IP de una instancia EC2:**
   ```powershell
   $instances = aws ec2 describe-instances `
     --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
     --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
     --output json | ConvertFrom-Json
   
   $instanceIp = $instances[0][1]
   Write-Host "IP de la instancia: $instanceIp" -ForegroundColor Green
   ```

3. **Conectarte por SSH y ejecutar comandos:**
   ```powershell
   # Configurar ruta a tu key (ajusta la ruta)
   $keyPath = "C:\ruta\a\tu-key.pem"
   
   # Instalar stress-ng
   Write-Host "Instalando stress-ng..." -ForegroundColor Yellow
   ssh -i $keyPath -o StrictHostKeyChecking=no ec2-user@$instanceIp "sudo yum install -y stress-ng"
   
   # Generar carga de CPU (en segundo plano)
   Write-Host "Generando carga de CPU..." -ForegroundColor Yellow
   ssh -i $keyPath -o StrictHostKeyChecking=no ec2-user@$instanceIp "nohup sudo stress-ng --cpu 4 --timeout 600s > /tmp/stress-ng.log 2>&1 &"
   
   Write-Host "✓ Carga de CPU iniciada. Espera 10-15 minutos..." -ForegroundColor Green
   ```

4. **Esperar 10-15 minutos y verificar en CloudWatch Dashboard**

5. **Detener la carga:**
   ```powershell
   ssh -i $keyPath -o StrictHostKeyChecking=no ec2-user@$instanceIp "sudo pkill stress-ng"
   Write-Host "✓ Carga de CPU detenida" -ForegroundColor Green
   ```

---

## 📊 **PRUEBA 4: Verificar Estado de Alarmas**

### **Objetivo:** Ver el estado actual de todas las alarmas

### **Dónde ejecutar:** Desde PowerShell en tu computadora

### **Paso a paso:**

#### **Opción A: Usar el script**

1. **Abre PowerShell** en tu computadora
2. **Navega a la carpeta infra:**
   ```powershell
   cd C:\Users\jusef\OneDrive\Documentos\genius\infra
   ```
3. **Ejecuta el script:**
   ```powershell
   .\test-metrics.ps1
   ```
4. **Selecciona opción 4** (Verificar estado de alarmas)
5. **Verás el estado de las 3 alarmas:**
   - `genius-dev-unhealthy-hosts`
   - `genius-dev-http-5xx-errors`
   - `genius-dev-high-cpu`

#### **Opción B: Usar AWS CLI manualmente**

1. **Abre PowerShell** en tu computadora
2. **Ejecuta:**
   ```powershell
   # Ver todas las alarmas
   aws cloudwatch describe-alarms `
     --alarm-name-prefix "genius-dev-" `
     --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' `
     --output table
   ```

---

## 🔍 **PRUEBA 5: Verificar Métricas Directamente**

### **Objetivo:** Ver las métricas sin usar el dashboard

### **Dónde ejecutar:** Desde PowerShell en tu computadora

### **Paso a paso:**

1. **Abre PowerShell** en tu computadora

2. **Obtener el ARN del ALB:**
   ```powershell
   $ALB_ARN = aws elbv2 describe-load-balancers `
     --query 'LoadBalancers[?contains(LoadBalancerName, `genius-dev`)].LoadBalancerArn' `
     --output text
   
   Write-Host "ALB ARN: $ALB_ARN"
   ```

3. **Ver métricas de errores 5xx:**
   ```powershell
   $startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
   $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
   
   aws cloudwatch get-metric-statistics `
     --namespace AWS/ApplicationELB `
     --metric-name HTTPCode_Target_5XX_Count `
     --dimensions Name=LoadBalancer,Value=$ALB_ARN `
     --start-time $startTime `
     --end-time $endTime `
     --period 300 `
     --statistics Sum `
     --output table
   ```

---

## 📝 **RESUMEN: Todas las Pruebas desde PowerShell**

| Prueba | Herramienta | Comando Principal |
|--------|-------------|-------------------|
| **Health Checks** | PowerShell / Script | `.\test-metrics.ps1` → Opción 1 |
| **Errores 5xx** | PowerShell / Script | `.\test-metrics.ps1` → Opción 2 |
| **CPU Usage** | PowerShell + AWS SSM/SSH | `aws ssm send-command` o `ssh` |
| **Verificar Alarmas** | PowerShell / AWS CLI | `.\test-metrics.ps1` → Opción 4 |
| **Ver Métricas** | PowerShell / AWS CLI | `aws cloudwatch get-metric-statistics` |

---

## 🎯 **CHECKLIST RÁPIDO**

### **Para probar Widget 1 (Health Checks):**
- [ ] Abrir PowerShell en tu computadora
- [ ] Ejecutar `.\test-metrics.ps1` → Opción 1
- [ ] Esperar 2-5 minutos
- [ ] Abrir CloudWatch Dashboard
- [ ] Verificar Widget 1 muestra hosts saludables

### **Para probar Widget 3 (Errores 5xx):**
- [ ] Abrir PowerShell en tu computadora
- [ ] Ejecutar `.\test-metrics.ps1` → Opción 2
- [ ] Esperar 5-10 minutos
- [ ] Abrir CloudWatch Dashboard
- [ ] Verificar Widget 3 muestra errores

### **Para probar Widget 2 (CPU):**
- [ ] Abrir PowerShell en tu computadora
- [ ] Obtener Instance ID: `aws ec2 describe-instances ...`
- [ ] Instalar stress-ng: `aws ssm send-command ...`
- [ ] Ejecutar carga: `aws ssm send-command ...` (stress-ng)
- [ ] Esperar 10-15 minutos
- [ ] Abrir CloudWatch Dashboard
- [ ] Verificar Widget 2 muestra CPU alta
- [ ] Detener: `aws ssm send-command ...` (pkill stress-ng)

---

## ❓ **PREGUNTAS FRECUENTES**

### **¿Necesito instalar algo?**
- **En tu computadora:** 
  - PowerShell (ya viene con Windows)
  - AWS CLI (debe estar instalado y configurado)
  - Para SSH: Cliente SSH (opcional, si usas Opción B para CPU)
- **En la instancia EC2:** `stress-ng` (se instala automáticamente con los comandos)

### **¿Cómo obtengo la IP de la instancia?**
```powershell
aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=*genius-dev*" `
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' `
  --output table
```

### **¿Cómo ejecuto comandos en la instancia desde PowerShell?**
```powershell
# Opción A: Usar AWS Systems Manager (SSM) - RECOMENDADO
aws ssm send-command `
  --instance-ids <INSTANCE-ID> `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['comando-aqui']"

# Opción B: Usar SSH (si SSM no está disponible)
ssh -i C:\ruta\a\tu-key.pem ec2-user@<IP-INSTANCIA> "comando-aqui"
```

### **¿Dónde veo el dashboard?**
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status

---

## 🚀 **RECOMENDACIÓN**

**Para empezar rápido:**
1. Ejecuta el script `test-metrics.ps1` → Opción 1
2. Espera 5 minutos
3. Abre el dashboard de CloudWatch
4. Verifica que Widget 1 muestra datos

¡Eso es todo! 🎉
