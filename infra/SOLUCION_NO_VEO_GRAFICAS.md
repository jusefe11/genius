# 🔧 Solución: No Veo Cambios en las Gráficas

## ✅ Solución Inmediata (Más Probable)

### Paso 1: Cambiar el Rango de Tiempo

El problema más común es que el dashboard tiene un rango de tiempo **muy corto** (5 minutos).

**En el dashboard de CloudWatch:**

1. En la parte superior del dashboard, busca el selector de tiempo
2. Cambia de **"Personalizado (5m)"** a **"1h" (1 hora)** o **"3h" (3 horas)**
3. Haz clic en el botón de **actualizar** o espera a que se actualice automáticamente

**¿Por qué funciona?**
- Las métricas de CloudWatch tienen un retraso de **2-5 minutos** en aparecer
- Un rango de 5 minutos es demasiado corto y puede no capturar el momento exacto
- Con 1 hora o más, tienes más margen para ver el tráfico que generaste

---

## 🔍 Paso 2: Verificar que el Tráfico Llegó

Antes de revisar las gráficas, verifica que las peticiones realmente funcionaron:

### Verificar desde PowerShell:

```powershell
cd infra\envs\dev
$albUrl = "http://" + (terraform output -raw alb_dns_name)
Write-Host "Probando conectividad a: $albUrl" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 10
    Write-Host "✓ Conectividad OK - Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ El ALB está funcionando" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: No se pudo conectar al ALB" -ForegroundColor Red
    Write-Host "  Detalle: $($_.Exception.Message)" -ForegroundColor Yellow
}
```

**Si obtienes un error 502 o 503:**
- Las instancias del ASG no están saludables
- No hay aplicación corriendo en las instancias
- Ve al Paso 3

---

## ✅ Paso 3: Verificar que las Instancias Están Saludables

Si las peticiones fallan o las métricas no aparecen, verifica las instancias:

### Desde la Consola de AWS:

1. Ve a **EC2** → **Auto Scaling Groups**
2. Busca tu ASG: `genius-dev-asg`
3. Haz clic en él
4. Ve a la pestaña **"Instances"** o **"Activity"**
5. Verifica que:
   - Las instancias estén en estado **"InService"**
   - El health check diga **"Healthy"**
   - Si dice **"Unhealthy"**, las métricas no aparecerán

### Desde PowerShell (con AWS CLI):

```powershell
# Instalar AWS CLI si no lo tienes
# Ver instancias del ASG
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names genius-dev-asg --region us-east-1

# Ver estado de los targets del ALB
$tgArn = terraform output -raw target_group_arn
aws elbv2 describe-target-health --target-group-arn $tgArn --region us-east-1
```

---

## ⏱️ Paso 4: Generar Tráfico Nuevamente y Esperar

Si cambiaste el rango de tiempo a 1h o más, genera tráfico nuevamente:

```powershell
cd infra\envs\dev
$albUrl = "http://" + (terraform output -raw alb_dns_name)

Write-Host "Generando 100 peticiones..." -ForegroundColor Yellow
for ($i = 1; $i -le 100; $i++) {
    try {
        Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing -TimeoutSec 5 | Out-Null
        if ($i % 10 -eq 0) {
            Write-Host "  [$i/100] Peticiones completadas..." -ForegroundColor Cyan
        }
    } catch {
        Write-Host "  Error en petición $i" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 300
}
Write-Host "✓ Tráfico generado" -ForegroundColor Green
Write-Host "`nEspera 3-5 minutos y actualiza el dashboard (F5)" -ForegroundColor Yellow
```

---

## 📊 Paso 5: Verificar en CloudWatch Metrics Directamente

Si aún no ves datos en el dashboard, verifica las métricas directamente:

1. Ve a **CloudWatch** → **Metrics** → **All metrics**
2. Busca **"ApplicationELB"**
3. Haz clic en **"Per-LB Metrics"** o **"Per-TG Metrics"**
4. Busca tu ALB o Target Group
5. Selecciona las métricas:
   - **RequestCount**
   - **TargetResponseTime**
   - **HealthyHostCount**

**Si las métricas aparecen aquí pero no en el dashboard:**
- El problema es el dashboard o el rango de tiempo
- Usa un rango de tiempo más amplio (3h o 1d)

**Si las métricas NO aparecen aquí:**
- El problema es que no hay tráfico llegando
- Verifica las instancias del ASG (Paso 3)
- Verifica la conectividad (Paso 2)

---

## 🎯 Checklist de Verificación

Usa este checklist para identificar el problema:

- [ ] **Cambié el rango de tiempo a 1h o más** (no 5m)
- [ ] **Las peticiones HTTP funcionan** (no dan error 502/503)
- [ ] **Las instancias del ASG están "Healthy"**
- [ ] **Generé tráfico nuevamente** después de cambiar el rango de tiempo
- [ ] **Esperé 3-5 minutos** después de generar el tráfico
- [ ] **Actualicé el dashboard** (F5)
- [ ] **Verifiqué las métricas directamente** en CloudWatch → Metrics

---

## 🐛 Problemas Específicos y Soluciones

### Problema: "El rango de tiempo no se puede cambiar"

**Solución:**
- Haz clic directamente en el número de tiempo (ej: "5m")
- O busca un botón de configuración ⚙️ cerca del selector de tiempo
- Algunos dashboards permiten cambiar el rango desde el menú de configuración del widget

### Problema: "Las peticiones dan error 502 Bad Gateway"

**Causa:** Las instancias no están saludables o no responden.

**Solución:**
1. Ve a **EC2** → **Target Groups**
2. Selecciona tu target group: `genius-dev-tg`
3. Ve a la pestaña **"Targets"**
4. Verifica el estado de salud de cada instancia
5. Si están "Unhealthy", revisa:
   - Que la aplicación esté corriendo en el puerto 8080 (por defecto)
   - Que el health check path sea correcto (`/` por defecto)
   - Que los security groups permitan el tráfico

### Problema: "Healthy Hosts muestra '--' siempre"

**Causa:** No hay instancias saludables o el Target Group está vacío.

**Solución:**
1. Verifica que el ASG tenga instancias: **EC2** → **Auto Scaling Groups** → Tu ASG → Pestaña **"Instances"**
2. Verifica que las instancias estén registradas en el Target Group
3. Si no hay instancias, el ASG puede estar en proceso de crear instancias (espera unos minutos)

### Problema: "Request Count muestra 0 o no hay datos después de generar mucho tráfico"

**Causas posibles:**
1. Las peticiones no están llegando al ALB (error de DNS o conectividad)
2. El rango de tiempo es incorrecto (muy corto o en el pasado)
3. Estás generando peticiones a la URL incorrecta

**Solución:**
```powershell
# Verifica la URL correcta
cd infra\envs\dev
terraform output alb_dns_name

# Verifica que la petición funcione
$albUrl = "http://" + (terraform output -raw alb_dns_name)
Invoke-WebRequest -Uri $albUrl -Method GET -UseBasicParsing
```

---

## 💡 Resumen: Pasos Rápidos

1. **CAMBIAR RANGO DE TIEMPO** a 1h o 3h (no 5m) ⚠️ **LO MÁS IMPORTANTE**
2. Verificar que las peticiones funcionan (no error 502/503)
3. Verificar que las instancias están "Healthy"
4. Generar tráfico nuevamente (100 peticiones)
5. Esperar 3-5 minutos
6. Actualizar el dashboard (F5)

**En el 90% de los casos, el problema es el rango de tiempo de 5 minutos.**
