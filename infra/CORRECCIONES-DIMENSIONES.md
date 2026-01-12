# Correcciones de Dimensiones en CloudWatch

## Problema Identificado

Las alarmas y el dashboard estaban usando dimensiones incorrectas para las metricas de CloudWatch, lo que impedia que las alarmas se activaran correctamente.

## Cambios Realizados

### 1. **Alarma: Unhealthy Hosts** ✅

**Antes:**
```terraform
dimensions = {
  TargetGroup  = var.target_group_arn  # ❌ ARN completo
  LoadBalancer = var.alb_arn           # ❌ ARN completo
}
```

**Despues:**
```terraform
dimensions = {
  TargetGroup  = local.target_group_identifier  # ✅ "targetgroup/name/id"
  LoadBalancer = local.alb_name                 # ✅ Nombre del ALB
}
```

### 2. **Alarma: HTTP 5xx Errors** ✅

**Antes:**
```terraform
dimensions = {
  LoadBalancer = var.alb_arn  # ❌ ARN completo
}
```

**Despues:**
```terraform
dimensions = {
  LoadBalancer = local.alb_name  # ✅ Nombre del ALB
}
```

### 3. **Dashboard: Widgets de Health Checks** ✅

**Antes:**
```terraform
"TargetGroup",
var.target_group_name,  # ❌ Solo el nombre
```

**Despues:**
```terraform
"TargetGroup",
local.target_group_identifier,  # ✅ "targetgroup/name/id"
```

### 4. **Local Variables Agregadas** ✅

Se agrego el calculo del identificador del Target Group:

```terraform
locals {
  alb_name = split("/", var.alb_arn)[length(split("/", var.alb_arn)) - 1]
  
  # Target Group identifier: formato "targetgroup/name/id" (requerido por CloudWatch)
  target_group_identifier = split(":", var.target_group_arn)[5]
  
  common_tags = { ... }
}
```

## Formato Correcto de Dimensiones

### Para Metricas de ApplicationELB:

- **LoadBalancer**: Nombre del ALB (ultima parte del ARN)
  - Ejemplo: `app/genius-dev-alb/1234567890abcdef`
  - Se obtiene: `split("/", alb_arn)[length(split("/", alb_arn)) - 1]`

- **TargetGroup**: Identificador en formato "targetgroup/name/id"
  - Ejemplo: `targetgroup/genius-dev-tg/abc123def456`
  - Se obtiene: `split(":", target_group_arn)[5]`

### Para Metricas de EC2:

- **AutoScalingGroupName**: Nombre del ASG (ya estaba correcto)
  - Ejemplo: `genius-dev-asg`

## Archivos Modificados

- `infra/modules/cloudwatch/main.tf`
  - Alarma `unhealthy_hosts`: Corregidas dimensiones
  - Alarma `http_5xx_errors`: Corregida dimension
  - Dashboard: Corregidos widgets de Health Checks
  - Locals: Agregado `target_group_identifier`

## Accion Requerida

**Aplicar los cambios con Terraform:**

```powershell
cd C:\Users\jusef\OneDrive\Documentos\genius\infra\envs\dev
terraform plan   # Revisar los cambios
terraform apply  # Aplicar los cambios
```

## Verificacion

Despues de aplicar los cambios, verifica que las alarmas funcionan:

```powershell
# Verificar estado de las alarmas
aws cloudwatch describe-alarms `
    --alarm-name-prefix "genius-dev-" `
    --query 'MetricAlarms[*].[AlarmName,StateValue,Dimensions]' `
    --output table

# Verificar que las dimensiones son correctas
aws cloudwatch describe-alarms `
    --alarm-names "genius-dev-unhealthy-hosts" "genius-dev-http-5xx-errors" `
    --query 'MetricAlarms[*].[AlarmName,Dimensions]' `
    --output json
```

## Notas Importantes

1. **Las dimensiones deben coincidir exactamente** entre:
   - Las alarmas
   - El dashboard
   - Las metricas reales de CloudWatch

2. **El formato del Target Group es critico:**
   - ❌ ARN completo: `arn:aws:elasticloadbalancing:...`
   - ❌ Solo nombre: `genius-dev-tg`
   - ✅ Identificador: `targetgroup/genius-dev-tg/abc123`

3. **El formato del LoadBalancer:**
   - ❌ ARN completo: `arn:aws:elasticloadbalancing:...`
   - ✅ Nombre: `app/genius-dev-alb/1234567890abcdef`

## Impacto

- ✅ Las alarmas ahora deberian activarse correctamente
- ✅ El dashboard mostrara las metricas correctamente
- ✅ Las dimensiones coinciden entre alarmas, dashboard y metricas
