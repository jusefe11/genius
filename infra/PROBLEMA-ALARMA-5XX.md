# Problema: La Alarma de Errores 5xx No Se Activa

## Problemas Encontrados y Corregidos

### 1. **Dimension Incorrecta en la Alarma** ✅ CORREGIDO

**Problema:**
La alarma estaba usando el ARN completo del ALB (`var.alb_arn`) en lugar del nombre del ALB.

**Sintoma:**
- La alarma existe pero nunca se activa
- Las metricas no coinciden con la dimension de la alarma

**Solucion:**
Se cambio la dimension de `var.alb_arn` a `local.alb_name` en:
- `infra/modules/cloudwatch/main.tf` - Alarma `http_5xx_errors`
- `infra/modules/cloudwatch/main.tf` - Alarma `unhealthy_hosts`

**Accion Requerida:**
```bash
cd infra/envs/dev
terraform apply
```

### 2. **El Script No Genera Errores 5xx Reales** ✅ MEJORADO

**Problema:**
El script intentaba generar errores 5xx haciendo peticiones a endpoints que no existen, pero eso devuelve 404 (Not Found), no 500 (Internal Server Error).

**Sintoma:**
- El script dice "Error 5xx generado" pero en realidad son 404
- La alarma no se activa porque no hay errores 5xx reales

**Solucion:**
Se mejoro el script `test-metrics.ps1` para:
- Intentar multiples metodos y endpoints
- Detectar correctamente si es 4xx o 5xx
- Mostrar advertencias si no se generan errores 5xx reales
- Ofrecer alternativas para generar errores 5xx

## Como Generar Errores 5xx Reales

### Opcion 1: Detener el Servicio Temporalmente (RECOMENDADO)

```powershell
# 1. Obtener una instancia del ASG
$instanceId = (aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*genius-dev*" "Name=instance-state-name,Values=running" `
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

# 2. Detener el servicio (ajusta segun tu aplicacion)
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[\"sudo systemctl stop tu-servicio\"]"

# 3. Generar peticiones al ALB (ahora deberian devolver 502 o 503)
.\test-metrics.ps1
# Selecciona opcion 4

# 4. Espera 5-10 minutos y verifica la alarma

# 5. Restaurar el servicio
aws ssm send-command `
    --instance-ids $instanceId `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[\"sudo systemctl start tu-servicio\"]"
```

### Opcion 2: Modificar Temporalmente la Aplicacion

Si tu aplicacion tiene un endpoint de prueba o puedes modificar temporalmente el codigo:

```python
# Ejemplo en Python/Flask
@app.route('/test-error-500')
def test_error():
    return "Internal Server Error", 500
```

Luego hacer peticiones a ese endpoint:
```powershell
for ($i = 1; $i -le 10; $i++) {
    Invoke-WebRequest -Uri "$albUrl/test-error-500" -UseBasicParsing
    Start-Sleep -Seconds 1
}
```

### Opcion 3: Usar Apache Bench para Generar Carga

```bash
# Generar muchas peticiones que fallen
ab -n 100 -c 10 http://$ALB_DNS/endpoint-que-no-existe
```

## Verificar que la Alarma Funciona

### 1. Verificar el Estado de la Alarma

```powershell
aws cloudwatch describe-alarms `
    --alarm-names "genius-dev-http-5xx-errors" `
    --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' `
    --output table
```

**Estados posibles:**
- `OK`: No hay errores 5xx (o menos de 5 en 5 minutos)
- `ALARM`: Hay mas de 5 errores 5xx en 5 minutos ✅
- `INSUFFICIENT_DATA`: No hay datos suficientes

### 2. Verificar las Metricas Directamente

```powershell
# Obtener el nombre del ALB
$albName = (terraform output -raw alb_arn).Split("/")[-1]

# Ver metricas de errores 5xx en los ultimos 15 minutos
$startTime = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
$endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")

aws cloudwatch get-metric-statistics `
    --namespace "AWS/ApplicationELB" `
    --metric-name "HTTPCode_Target_5XX_Count" `
    --dimensions "Name=LoadBalancer,Value=$albName" `
    --start-time $startTime `
    --end-time $endTime `
    --period 300 `
    --statistics Sum `
    --output table
```

### 3. Verificar el Dashboard

1. Ve a CloudWatch Dashboard: `genius-dev-application-status`
2. Cambia el periodo de tiempo a **1 hora** o **3 horas**
3. Verifica el Widget 3: "Errores HTTP 5xx"
4. Deberias ver una linea naranja con valores > 0

## Checklist de Verificacion

- [ ] Ejecute `terraform apply` para aplicar los cambios en la alarma
- [ ] Verifique que la dimension de la alarma es correcta (nombre del ALB, no ARN)
- [ ] Genere errores 5xx reales (no solo 404)
- [ ] Espere 5-10 minutos para que las metricas se actualicen
- [ ] Verifique el estado de la alarma con AWS CLI
- [ ] Verifique el dashboard con periodo de tiempo amplio (1h o 3h)

## Notas Importantes

1. **La alarma evalua en periodos de 5 minutos**: Necesitas mas de 5 errores 5xx en un periodo de 5 minutos para que se active.

2. **Las metricas pueden tardar 2-5 minutos**: Despues de generar errores, espera antes de verificar.

3. **404 NO cuenta como 5xx**: Solo errores 500, 502, 503, 504 cuentan para la alarma.

4. **La dimension debe coincidir**: El dashboard y la alarma deben usar el mismo formato (nombre del ALB, no ARN).

## Si Aun No Funciona

1. **Ejecuta el diagnostico:**
   ```powershell
   .\diagnostico-dashboard.ps1
   ```

2. **Verifica las dimensiones manualmente:**
   ```powershell
   # Ver la configuracion de la alarma
   aws cloudwatch describe-alarms --alarm-names "genius-dev-http-5xx-errors" | ConvertFrom-Json | Select-Object -ExpandProperty MetricAlarms | Select-Object AlarmName, Dimensions
   ```

3. **Verifica que hay metricas disponibles:**
   ```powershell
   # Ver todas las metricas disponibles para el ALB
   aws cloudwatch list-metrics --namespace "AWS/ApplicationELB" --dimensions "Name=LoadBalancer,Value=<ALB_NAME>"
   ```
