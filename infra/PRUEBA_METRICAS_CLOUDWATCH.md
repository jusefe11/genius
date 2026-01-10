# 🧪 Cómo Probar que las Métricas de CloudWatch Funcionan

Guía rápida para generar actividad y verificar que las métricas aparezcan en el dashboard.

---

## 📋 Paso 1: Obtener la URL de tu Aplicación

Primero, necesitas la URL del Application Load Balancer (ALB) para generar tráfico.

### En PowerShell:

```powershell
cd infra\envs\dev
terraform output alb_dns_name
```

**Ejemplo de salida:**
```
alb_dns_name = "genius-dev-alb-1234567890.us-east-1.elb.amazonaws.com"
```

Anota esta URL, la necesitarás en los siguientes pasos.

---

## 🚀 Paso 2: Generar Tráfico para Activar las Métricas

### Opción A: Usar PowerShell para Hacer Peticiones HTTP

```powershell
# Reemplaza ALB_DNS_NAME con la URL que obtuviste
$albUrl = "http://genius-dev-alb-1234567890.us-east-1.elb.amazonaws.com"

# Hacer 50 peticiones para generar tráfico
for ($i = 1; $i -le 50; $i++) {
    try {
        Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing | Out-Null
        Write-Host "Petición $i completada"
        Start-Sleep -Milliseconds 500  # Esperar 0.5 segundos entre peticiones
    } catch {
        Write-Host "Error en petición $i : $_" -ForegroundColor Yellow
    }
}
Write-Host "¡50 peticiones completadas!" -ForegroundColor Green
```

### Opción B: Usar curl (si está disponible)

```powershell
# Reemplaza ALB_DNS_NAME con tu URL
$albUrl = "http://genius-dev-alb-1234567890.us-east-1.elb.amazonaws.com"

# Hacer 50 peticiones
1..50 | ForEach-Object {
    curl $albUrl | Out-Null
    Write-Host "Petición $_ completada"
    Start-Sleep -Milliseconds 500
}
```

### Opción C: Usar el Navegador

1. Copia la URL del ALB (del paso 1)
2. Ábrela en tu navegador: `http://genius-dev-alb-XXXXX.us-east-1.elb.amazonaws.com`
3. **Actualiza la página varias veces** (F5 o Ctrl+R)
4. Repite esto 20-30 veces para generar tráfico

### Opción D: Usar un Script Python (si tienes Python)

Crea un archivo `test_metrics.py`:

```python
import requests
import time

alb_url = "http://genius-dev-alb-1234567890.us-east-1.elb.amazonaws.com"

print("Generando tráfico hacia la aplicación...")
for i in range(50):
    try:
        response = requests.get(alb_url, timeout=5)
        print(f"Petición {i+1}/50 - Status: {response.status_code}")
    except Exception as e:
        print(f"Error en petición {i+1}: {e}")
    time.sleep(0.5)  # Esperar 0.5 segundos

print("¡Tráfico generado! Revisa CloudWatch en 2-3 minutos.")
```

Ejecuta:
```powershell
python test_metrics.py
```

---

## ⏱️ Paso 3: Esperar y Verificar en CloudWatch

**Importante:** Las métricas en CloudWatch pueden tardar **2-5 minutos** en aparecer.

1. Ve a la consola de AWS CloudWatch
2. Abre el dashboard: `genius-dev-application-status`
3. Espera 2-5 minutos después de generar el tráfico
4. **Actualiza el dashboard** (F5 o el botón de refresh)

### ¿Qué Deberías Ver?

Después de generar tráfico:

✅ **Request Count**: Debería mostrar un gráfico con barras/picos (múltiples peticiones)
✅ **Response Time**: Debería mostrar un gráfico con tiempo de respuesta en segundos
✅ **Healthy Hosts**: Debería mostrar un número (2 si tienes 2 instancias en el ASG)
✅ **CPU Usage**: Puede mostrar actividad si las instancias procesan las peticiones

---

## 📊 Paso 4: Verificar las Alarmas

Ve a **CloudWatch** → **Alarms** y verifica que las 3 alarmas existan:

1. `genius-dev-unhealthy-hosts` - Debe estar en estado **OK** (verde)
2. `genius-dev-http-5xx-errors` - Debe estar en estado **OK** (verde) si no hay errores
3. `genius-dev-high-cpu` - Debe estar en estado **OK** (verde) si CPU < 80%

---

## 🔬 Paso 5: Probar que las Alarmas Funcionan (Opcional)

### Probar la Alarma de CPU Alta:

Si quieres probar que la alarma de CPU funciona, puedes hacerlo temporalmente:

**⚠️ ADVERTENCIA:** Esto aumentará el uso de CPU en tus instancias.

1. Conecta por SSH a una instancia (si tienes acceso)
2. Ejecuta un comando que consuma CPU:
   ```bash
   # Esto consumirá CPU por 60 segundos
   timeout 60 yes > /dev/null &
   ```
3. Verifica en CloudWatch si la alarma se activa (debe cambiar a **ALARM** en rojo)

**Para detener:**
```bash
pkill yes
```

### Probar la Alarma de Errores 5xx:

Si tu aplicación tiene un endpoint que genera errores, puedes probar accediendo a él.

---

## 📝 Checklist de Verificación

Después de generar tráfico, verifica:

- [ ] **Request Count** muestra datos (no "No hay datos disponibles")
- [ ] **Response Time** muestra datos (tiempos de respuesta en segundos)
- [ ] **Healthy Hosts** muestra un número (no "--")
- [ ] **CPU Usage** muestra actividad (aunque sea baja)
- [ ] Las 3 alarmas existen en CloudWatch → Alarms
- [ ] Las alarmas están en estado **OK** (verde)

---

## 🐛 Solución de Problemas

### Problema: "No veo cambios en las gráficas" (PRIMERO VERIFICA ESTO)

**⚠️ PROBLEMA COMÚN:** El rango de tiempo del dashboard está en **5 minutos** o muy corto.

**Solución inmediata:**
1. En el dashboard de CloudWatch, en la parte superior, verás el selector de tiempo
2. **Cambia de "Personalizado (5m)" a "1h" (1 hora)** o **"3h" (3 horas)**
3. Haz clic en **"Actualizar"** o espera a que se actualice automáticamente
4. Las métricas deberían aparecer ahora

**¿Por qué?**
- Las métricas de CloudWatch tienen un retraso de 2-5 minutos
- Un rango de 5 minutos es demasiado corto y puede no capturar el momento exacto del tráfico
- Usar 1 hora o más te da más margen para ver el tráfico que generaste

### Problema: "Sigo viendo 'No hay datos disponibles' después de generar tráfico"

**Causas posibles:**
1. Las peticiones no llegaron a la aplicación (error de conexión)
2. No esperaste suficiente tiempo (las métricas tardan 2-5 minutos)
3. Las instancias del ASG no están saludables

**Solución:**
```powershell
# Verifica que las peticiones funcionan
$albUrl = "http://TU-ALB-DNS.us-east-1.elb.amazonaws.com"
Invoke-WebRequest -Uri $albUrl -Method GET
```

Si obtienes un error, verifica:
- Que el ALB existe y está funcionando
- Que las instancias del ASG están en estado "healthy"
- Que el puerto correcto está abierto (8080 por defecto)

### Problema: "Las peticiones fallan con error 502 o 503"

**Causa:** Las instancias del ASG no están saludables o no hay aplicación corriendo.

**Solución:**
1. Ve a **EC2** → **Auto Scaling Groups**
2. Selecciona tu ASG (`genius-dev-asg`)
3. Ve a la pestaña **"Activity"** o **"Instances"**
4. Verifica que las instancias estén en estado **"InService"** y **"Healthy"**

### Problema: "Request Count muestra datos pero Response Time no"

**Causa:** La métrica de Response Time puede tardar un poco más en aparecer.

**Solución:** Espera 5-10 minutos y actualiza el dashboard.

---

## 📌 Comandos Rápidos de PowerShell

Copia y pega este script completo (reemplaza `ALB_DNS_NAME`):

```powershell
# Obtener la URL del ALB
cd infra\envs\dev
$albUrl = "http://" + (terraform output -raw alb_dns_name)
Write-Host "URL del ALB: $albUrl" -ForegroundColor Cyan

# Generar tráfico
Write-Host "`nGenerando tráfico (50 peticiones)..." -ForegroundColor Yellow
for ($i = 1; $i -le 50; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 5
        Write-Host "✓ Petición $i/50 - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Error en petición $i : $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "`n¡Tráfico generado! Revisa CloudWatch en 2-3 minutos." -ForegroundColor Green
Write-Host "Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status" -ForegroundColor Cyan
```

---

## 🎯 Resumen

**Pasos rápidos:**

1. **Obtén la URL del ALB**: `terraform output alb_dns_name`
2. **Genera tráfico**: Haz 30-50 peticiones HTTP a esa URL
3. **Espera 2-5 minutos** para que las métricas se actualicen
4. **Revisa CloudWatch**: Abre el dashboard y verifica que aparezcan datos

¡Listo! Con esto deberías ver todas las métricas funcionando correctamente.
