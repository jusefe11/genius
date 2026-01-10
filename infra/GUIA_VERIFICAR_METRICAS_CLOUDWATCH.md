# Guía para Verificar Métricas de CloudWatch en la Consola de AWS

Esta guía te ayudará a verificar que las métricas de CloudWatch están correctamente configuradas y funcionando.

## 📋 Métricas Configuradas

El módulo de CloudWatch crea los siguientes recursos:

1. **Dashboard**: `{project_name}-{environment}-application-status`
   - Para el ambiente **dev**: `genius-dev-application-status`
   - Para el ambiente **qa**: `genius-qa-application-status`
   - Para el ambiente **prod**: `genius-prod-application-status`

2. **3 Alarmas de CloudWatch**:
   - `genius-{environment}-unhealthy-hosts` - Instancias no saludables
   - `genius-{environment}-http-5xx-errors` - Errores HTTP 5xx
   - `genius-{environment}-high-cpu` - CPU alto

---

## 🎯 Método 1: Verificar el Dashboard (Recomendado)

El dashboard es la forma más fácil de ver todas las métricas en un solo lugar.

### Paso 1: Acceder a CloudWatch
1. Inicia sesión en la [Consola de AWS](https://console.aws.amazon.com/)
2. En la barra de búsqueda superior, escribe **"CloudWatch"**
3. Selecciona **"CloudWatch"** en los resultados

### Paso 2: Abrir el Dashboard
1. En el menú lateral izquierdo, expande **"Dashboards"** y haz clic en **"Dashboards"**
2. Busca el dashboard con el nombre: **`genius-{ambiente}-application-status`**
   - Por ejemplo: `genius-dev-application-status` para el ambiente de desarrollo
3. Haz clic en el nombre del dashboard para abrirlo

### Paso 3: Verificar los Widgets
Deberías ver 4 widgets en el dashboard:

#### Widget 1: Healthy Hosts
- **Tipo**: Valor único (Single Value)
- **Métrica**: Número de hosts saludables en el Target Group
- **¿Qué verificar?**: Debería mostrar un número (típicamente 2 o más si tu ASG tiene instancias corriendo)

#### Widget 2: Request Count
- **Tipo**: Gráfico de línea (Time Series)
- **Métrica**: Cantidad de solicitudes HTTP
- **¿Qué verificar?**: Debería mostrar un gráfico de línea. Si no hay tráfico, puede estar en 0

#### Widget 3: Response Time
- **Tipo**: Gráfico de línea (Time Series)
- **Métrica**: Tiempo de respuesta promedio en segundos
- **¿Qué verificar?**: Debería mostrar valores en segundos (típicamente entre 0.01 y 2 segundos)

#### Widget 4: CPU Usage
- **Tipo**: Gráfico de línea (Time Series)
- **Métrica**: Uso de CPU del Auto Scaling Group en porcentaje
- **¿Qué verificar?**: Debería mostrar un porcentaje (0-100%)

### ✅ Qué Buscar para Confirmar que Está Bien:
- ✅ Todos los widgets están visibles
- ✅ Los widgets muestran datos (no "No data")
- ✅ Si hay tráfico, deberías ver valores en Request Count y Response Time
- ✅ Healthy Hosts muestra el número correcto de instancias

---

## 🔔 Método 2: Verificar las Alarmas

### Paso 1: Acceder a las Alarmas
1. En el menú lateral izquierdo de CloudWatch, haz clic en **"Alarms"** (debajo de "Metrics")
2. Verás una lista de todas las alarmas

### Paso 2: Buscar las Alarmas del Proyecto
Busca las siguientes alarmas (reemplaza `{environment}` con dev, qa o prod):

1. **`genius-{environment}-unhealthy-hosts`**
   - **Estado esperado**: "OK" (verde) si no hay instancias no saludables
   - **Métrica**: `UnHealthyHostCount`
   - **Namespace**: `AWS/ApplicationELB`

2. **`genius-{environment}-http-5xx-errors`**
   - **Estado esperado**: "OK" (verde) si no hay errores 5xx
   - **Métrica**: `HTTPCode_Target_5XX_Count`
   - **Namespace**: `AWS/ApplicationELB`

3. **`genius-{environment}-high-cpu`**
   - **Estado esperado**: "OK" (verde) si el CPU está por debajo del 80%
   - **Métrica**: `CPUUtilization`
   - **Namespace**: `AWS/EC2`

### Paso 3: Verificar Detalles de una Alarma
1. Haz clic en el nombre de una alarma
2. En la sección **"Metric"**, verifica:
   - ✅ El **Namespace** es correcto (`AWS/ApplicationELB` o `AWS/EC2`)
   - ✅ El **Metric name** es correcto
   - ✅ Las **Dimensions** muestran los recursos correctos (ALB ARN, Target Group ARN, o ASG name)
3. En la sección **"Configuration"**, verifica:
   - ✅ El **Threshold** es correcto
   - ✅ El **Period** es correcto (60s para unhealthy hosts, 300s para las demás)
   - ✅ El **Evaluation periods** es correcto

### ✅ Qué Buscar para Confirmar que Está Bien:
- ✅ Las 3 alarmas están presentes
- ✅ Los nombres coinciden con el patrón esperado
- ✅ Los estados son "OK" (si no hay problemas)
- ✅ Las dimensiones apuntan a los recursos correctos

---

## 📊 Método 3: Verificar Métricas Individuales

Puedes verificar cada métrica individualmente en CloudWatch.

### Paso 1: Acceder a las Métricas
1. En el menú lateral izquierdo, expande **"Metrics"** y haz clic en **"All metrics"**
2. Aquí verás todas las métricas organizadas por namespace

### Paso 2: Verificar Métricas del ALB (Application Load Balancer)
1. En la pestaña **"Browse"**, busca y haz clic en **"ApplicationELB"**
2. Verifica que puedas encontrar:
   - **HealthyHostCount** - Debería aparecer con la dimensión de tu Target Group
   - **RequestCount** - Debería aparecer con la dimensión de tu Load Balancer
   - **TargetResponseTime** - Debería aparecer con la dimensión de tu Load Balancer
   - **HTTPCode_Target_5XX_Count** - Debería aparecer con la dimensión de tu Load Balancer
   - **UnHealthyHostCount** - Debería aparecer con la dimensión de tu Target Group

3. Haz clic en una métrica para ver su gráfico
4. En la sección **"Graphed metrics"**, verifica las dimensiones:
   - Deberías ver el ARN completo de tu ALB o Target Group

### Paso 3: Verificar Métricas del ASG (Auto Scaling Group)
1. En la pestaña **"Browse"**, busca y haz clic en **"EC2"**
2. Haz clic en **"By Auto Scaling Group"**
3. Busca **"CPUUtilization"**
4. Verifica que puedas encontrar la métrica con la dimensión de tu Auto Scaling Group

### ✅ Qué Buscar para Confirmar que Está Bien:
- ✅ Puedes encontrar todas las métricas mencionadas
- ✅ Las métricas tienen datos (puede tomar unos minutos después del despliegue)
- ✅ Las dimensiones coinciden con tus recursos (ALB, Target Group, ASG)

---

## 🔍 Método 4: Usar Terraform Outputs

Si quieres acceder rápidamente al dashboard desde Terraform:

1. Navega a la carpeta del ambiente (ej: `infra/envs/dev/`)
2. Ejecuta: `terraform output`
3. Busca el output `cloudwatch_dashboard_url`
4. Copia la URL y ábrela en tu navegador

---

## ⚠️ Solución de Problemas Comunes

### Problema: "No data" en los widgets del dashboard
**Causas posibles**:
- Los recursos (ALB, ASG) están recién creados y aún no hay datos
- No hay tráfico hacia la aplicación
- Las instancias del ASG no están saludables

**Solución**:
- Espera 5-10 minutos después del despliegue
- Genera tráfico haciendo una petición HTTP al ALB
- Verifica que las instancias del ASG estén en estado "healthy"

### Problema: No encuentro el dashboard
**Causas posibles**:
- El dashboard no se creó correctamente
- Estás buscando en la región incorrecta
- El nombre del proyecto o ambiente es diferente

**Solución**:
- Verifica la región en la consola de AWS (debería ser `us-east-1` por defecto)
- Verifica el nombre exacto del dashboard en los outputs de Terraform
- Verifica que el módulo CloudWatch se haya ejecutado correctamente

### Problema: Las alarmas muestran "Insufficient data"
**Causas posibles**:
- Los recursos acaban de crearse
- Las métricas aún no tienen suficientes datos

**Solución**:
- Espera 10-15 minutos después del despliegue
- Verifica que los recursos (ALB, Target Group, ASG) existan y estén funcionando
- Genera algo de tráfico para que las métricas comiencen a recopilar datos

### Problema: Las dimensiones en las métricas están vacías o incorrectas
**Causas posibles**:
- Los ARNs o nombres de recursos no se pasaron correctamente al módulo
- Los recursos se eliminaron o recrearon

**Solución**:
- Verifica los valores de los outputs del módulo ALB y Autoscaling
- Verifica que los recursos existan en la consola de AWS
- Re-ejecuta `terraform apply` si es necesario

---

## 📝 Checklist de Verificación

Usa este checklist para asegurarte de que todo está correctamente configurado:

### Dashboard
- [ ] El dashboard existe con el nombre correcto: `genius-{environment}-application-status`
- [ ] Los 4 widgets están visibles
- [ ] Healthy Hosts muestra un número (no "No data")
- [ ] Request Count está disponible (puede ser 0 si no hay tráfico)
- [ ] Response Time está disponible
- [ ] CPU Usage está disponible

### Alarmas
- [ ] `genius-{environment}-unhealthy-hosts` existe
- [ ] `genius-{environment}-http-5xx-errors` existe
- [ ] `genius-{environment}-high-cpu` existe
- [ ] Las alarmas tienen el namespace correcto
- [ ] Las alarmas tienen las dimensiones correctas
- [ ] Los umbrales (thresholds) son correctos

### Métricas
- [ ] Puedo encontrar `HealthyHostCount` en ApplicationELB
- [ ] Puedo encontrar `RequestCount` en ApplicationELB
- [ ] Puedo encontrar `TargetResponseTime` en ApplicationELB
- [ ] Puedo encontrar `CPUUtilization` en EC2 por Auto Scaling Group

---

## 🚀 Acceso Rápido

### URL Directa al Dashboard
Reemplaza `{region}` y `{environment}` según corresponda:

```
https://console.aws.amazon.com/cloudwatch/home?region={region}#dashboards:name=genius-{environment}-application-status
```

**Ejemplo para dev en us-east-1**:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status
```

### Regiones Comunes
- `us-east-1` - US East (N. Virginia)
- `us-west-2` - US West (Oregon)
- `eu-west-1` - Europe (Ireland)

---

## 📚 Recursos Adicionales

- [Documentación de CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [Documentación de CloudWatch Alarmas](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Métricas de Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)
- [Métricas de EC2 y Auto Scaling](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html)
