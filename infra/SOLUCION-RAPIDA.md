# Solucion Rapida: No aparecen metricas en el Dashboard

## Problema
El dashboard muestra "No hay datos disponibles" aunque ejecutaste las pruebas.

## Soluciones Inmediatas

### 1. Cambiar el Periodo de Tiempo en CloudWatch (MAS IMPORTANTE)

**En el dashboard de CloudWatch:**
1. Arriba a la derecha, cambia el selector de tiempo
2. De "5 minutos" cambia a **"1 hora"** o **"3 horas"**
3. Presiona F5 para actualizar

**Por que funciona:**
- Las metricas pueden tardar 2-5 minutos en aparecer
- Un periodo de 5 minutos es muy corto
- Con 1 hora o mas, veras los datos historicos

### 2. Verificar que hay Instancias y Targets

Ejecuta el diagnostico:
```powershell
cd C:\Users\jusef\OneDrive\Documentos\genius\infra
.\diagnostico-dashboard.ps1
```

Esto verificara:
- Si hay instancias en el ASG
- Si hay targets registrados en el Target Group
- Si las metricas existen en CloudWatch

### 3. Generar Trafico Real

Si el diagnostico muestra que todo esta bien, genera mas trafico:

```powershell
.\test-metrics.ps1
# Selecciona opcion 1 (HealthyHostCount)
# Genera 100 peticiones (no 50)
```

Luego espera **5-10 minutos** y actualiza el dashboard con periodo de **1 hora**.

### 4. Verificar las Dimensiones

El dashboard usa estas dimensiones:
- **HealthyHostCount/UnHealthyHostCount**: `TargetGroup` + `LoadBalancer`
- **CPUUtilization**: `AutoScalingGroupName`
- **HTTPCode_Target_5XX_Count**: `LoadBalancer`

El diagnostico verificara si estas dimensiones coinciden.

## Checklist de Verificacion

- [ ] Cambie el periodo de tiempo a 1h o 3h
- [ ] Ejecute el diagnostico: `.\diagnostico-dashboard.ps1`
- [ ] Verifique que hay instancias en el ASG
- [ ] Verifique que hay targets registrados
- [ ] Genero trafico con el script
- [ ] Espero 5-10 minutos
- [ ] Actualice el dashboard (F5)

## Si Aun No Funciona

1. **Verifica que el ALB esta recibiendo trafico:**
   ```powershell
   # Obtener el DNS del ALB
   cd envs\dev
   terraform output alb_dns_name
   
   # Hacer una peticion manual
   Invoke-WebRequest -Uri "http://$(terraform output -raw alb_dns_name)" -UseBasicParsing
   ```

2. **Verifica las metricas directamente con AWS CLI:**
   ```powershell
   # Ver metricas de los ultimos 30 minutos
   aws cloudwatch get-metric-statistics `
     --namespace "AWS/ApplicationELB" `
     --metric-name "HealthyHostCount" `
     --dimensions "Name=TargetGroup,Value=<TG_IDENTIFIER>" "Name=LoadBalancer,Value=<ALB_NAME>" `
     --start-time (Get-Date).AddMinutes(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
     --end-time (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
     --period 60 `
     --statistics Average
   ```

3. **Verifica que el dashboard existe y esta actualizado:**
   ```powershell
   aws cloudwatch get-dashboard --dashboard-name "genius-dev-application-status"
   ```

## Causa Mas Probable

**El periodo de tiempo de 5 minutos es demasiado corto.**

Las metricas de CloudWatch:
- Se actualizan cada 60 segundos (para HealthyHostCount)
- Pueden tardar 2-5 minutos en aparecer
- Con un periodo de 5 minutos, si generaste trafico hace 6 minutos, no lo veras

**Solucion:** Cambia a 1 hora o 3 horas en el dashboard.
