# Alarmas CloudWatch - Resumen Completo

## Todas las Alarmas Configuradas

### 1. **genius-dev-no-healthy-hosts** ✅ NUEVA

**Metrica:** `HealthyHostCount`  
**Namespace:** `AWS/ApplicationELB`  
**Umbral:** < 1 host saludable  
**Periodo:** 60 segundos  
**Evaluaciones:** 1  
**Operador:** LessThanThreshold  
**Descripcion:** Alerta cuando no hay hosts saludables en el Target Group

**Cuando se activa:**
- Cuando `HealthyHostCount` es menor a 1
- Esto significa que NO hay instancias saludables disponibles
- Es una situacion critica: la aplicacion no esta disponible

**Como probar:**
- Detener todos los servicios en todas las instancias
- O detener todas las instancias del ASG

---

### 2. **genius-dev-unhealthy-hosts** ✅

**Metrica:** `UnHealthyHostCount`  
**Namespace:** `AWS/ApplicationELB`  
**Umbral:** > 0 hosts no saludables  
**Periodo:** 60 segundos  
**Evaluaciones:** 1  
**Operador:** GreaterThanThreshold  
**Descripcion:** Alerta cuando hay instancias no saludables en el Target Group

**Cuando se activa:**
- Cuando `UnHealthyHostCount` es mayor a 0
- Esto significa que hay al menos 1 instancia que fallo el health check
- Es una advertencia: hay instancias con problemas pero puede haber otras saludables

**Como probar:**
- Detener el servicio en UNA instancia (dejar otras funcionando)
- El script `test-metrics.ps1` opcion 2 te guia en esto

---

### 3. **genius-dev-http-5xx-errors** ✅

**Metrica:** `HTTPCode_Target_5XX_Count`  
**Namespace:** `AWS/ApplicationELB`  
**Umbral:** > 5 errores en 5 minutos  
**Periodo:** 300 segundos (5 minutos)  
**Evaluaciones:** 1  
**Operador:** GreaterThanThreshold  
**Descripcion:** Alerta cuando hay errores 5xx del servidor

**Cuando se activa:**
- Cuando hay mas de 5 errores 5xx en un periodo de 5 minutos
- Esto indica problemas en el servidor (500, 502, 503, 504)
- Es una advertencia: la aplicacion esta generando errores

**Como probar:**
- Generar errores 5xx reales (no 404)
- Detener temporalmente el servicio para generar 502/503
- O modificar la aplicacion para que devuelva 500

---

### 4. **genius-dev-high-cpu** ✅

**Metrica:** `CPUUtilization`  
**Namespace:** `AWS/EC2`  
**Umbral:** > 80% de CPU  
**Periodo:** 300 segundos (5 minutos)  
**Evaluaciones:** 2 (debe estar > 80% durante 10 minutos)  
**Operador:** GreaterThanThreshold  
**Descripcion:** Alerta cuando el CPU esta por encima del umbral

**Cuando se activa:**
- Cuando el CPU promedio del ASG es mayor a 80% durante 10 minutos
- Esto indica que las instancias estan bajo mucha carga
- Es una advertencia: puede afectar el rendimiento

**Como probar:**
- Ejecutar `stress-ng` en las instancias para generar carga de CPU
- El script `test-metrics.ps1` opcion 3 hace esto automaticamente

---

## Resumen de Alarmas por Metrica

| Metrica | Alarma | Umbral | Periodo | Evaluaciones |
|---------|--------|--------|---------|--------------|
| HealthyHostCount | `genius-dev-no-healthy-hosts` | < 1 | 60s | 1 |
| UnHealthyHostCount | `genius-dev-unhealthy-hosts` | > 0 | 60s | 1 |
| HTTPCode_Target_5XX_Count | `genius-dev-http-5xx-errors` | > 5 | 300s | 1 |
| CPUUtilization | `genius-dev-high-cpu` | > 80% | 300s | 2 |

---

## Verificar Todas las Alarmas

```powershell
# Ver estado de todas las alarmas
aws cloudwatch describe-alarms `
    --alarm-name-prefix "genius-dev-" `
    --query 'MetricAlarms[*].[AlarmName,StateValue,Threshold,MetricName]' `
    --output table
```

O usar el script:
```powershell
.\test-metrics.ps1
# Selecciona opcion 6
```

---

## Accion Requerida

**Para crear la nueva alarma `genius-dev-no-healthy-hosts`:**

```powershell
cd C:\Users\jusef\OneDrive\Documentos\genius\infra\envs\dev
terraform plan   # Revisar los cambios
terraform apply   # Aplicar los cambios
```

---

## Notas Importantes

1. **Todas las metricas ahora tienen alarmas**: Ya no hay metricas sin alarmas asociadas

2. **La alarma de HealthyHostCount es critica**: Se activa cuando NO hay hosts saludables (aplicacion no disponible)

3. **Las alarmas tienen diferentes periodos**:
   - Health checks: 60 segundos (mas rapido)
   - CPU y errores 5xx: 300 segundos (5 minutos)

4. **Las alarmas requieren diferentes evaluaciones**:
   - La mayoria: 1 evaluacion
   - CPU alta: 2 evaluaciones (10 minutos)

---

## Testing Completo

Para probar todas las alarmas:

1. **HealthyHostCount (sin hosts saludables):**
   - Detener todos los servicios en todas las instancias
   - Esperar 1-2 minutos
   - Verificar alarma: `genius-dev-no-healthy-hosts`

2. **UnHealthyHostCount (hosts no saludables):**
   - Detener servicio en UNA instancia
   - Esperar 1-2 minutos
   - Verificar alarma: `genius-dev-unhealthy-hosts`

3. **HTTPCode_Target_5XX_Count (errores 5xx):**
   - Generar mas de 5 errores 5xx en 5 minutos
   - Esperar 5-10 minutos
   - Verificar alarma: `genius-dev-http-5xx-errors`

4. **CPUUtilization (CPU alta):**
   - Generar carga de CPU > 80% durante 10 minutos
   - Esperar 10-15 minutos
   - Verificar alarma: `genius-dev-high-cpu`
