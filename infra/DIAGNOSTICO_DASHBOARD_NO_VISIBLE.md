# 🔍 Diagnóstico: Dashboard de CloudWatch No Visible

Si no ves el dashboard en CloudWatch → Panels → Dashboards, sigue estos pasos para identificar el problema.

---

## ✅ Paso 1: Verificar si el Dashboard Existe en Terraform

### 1.1 Verificar que el módulo CloudWatch está configurado

Navega a la carpeta de tu ambiente:
```bash
cd infra/envs/dev  # o qa, o prod según tu caso
```

Verifica que el módulo CloudWatch esté en `main.tf`:

**En PowerShell:**
```powershell
Select-String -Path main.tf -Pattern "module.*cloudwatch" -CaseSensitive:$false
```

**En Bash/Linux:**
```bash
grep -i "module.*cloudwatch" main.tf
```

**Deberías ver:**
```
module "cloudwatch" {
  source = "../../modules/cloudwatch"
  ...
}
```

✅ **Si ves el módulo**: Continúa al Paso 2
❌ **Si NO ves el módulo**: El módulo no está configurado. Revisa `main.tf`.

---

## ✅ Paso 2: Verificar el Estado de Terraform

### 2.1 Verificar el estado de Terraform

En la carpeta de tu ambiente, ejecuta:

```bash
terraform plan
```

**Busca en la salida:**
- Si dice `aws_cloudwatch_dashboard.main will be created` → El dashboard **NO se ha creado** aún
- Si dice `aws_cloudwatch_dashboard.main` (sin "will be created") → El dashboard **YA existe** en el estado

### 2.2 Verificar si el recurso existe en el estado

**En PowerShell:**
```powershell
terraform state list | Select-String cloudwatch
```

**En Bash/Linux:**
```bash
terraform state list | grep cloudwatch
```

**Deberías ver algo como:**
```
module.cloudwatch.aws_cloudwatch_dashboard.main
module.cloudwatch.aws_cloudwatch_metric_alarm.unhealthy_hosts
module.cloudwatch.aws_cloudwatch_metric_alarm.http_5xx_errors
module.cloudwatch.aws_cloudwatch_metric_alarm.high_cpu
```

✅ **Si ves `aws_cloudwatch_dashboard.main`**: El dashboard está en el estado de Terraform, continúa al Paso 3
❌ **Si NO lo ves**: El dashboard no se ha creado. Ve al Paso 6.

### 2.3 Verificar el nombre exacto del dashboard

**En PowerShell:**
```powershell
terraform state show module.cloudwatch.aws_cloudwatch_dashboard.main | Select-String dashboard_name
```

**En Bash/Linux:**
```bash
terraform state show module.cloudwatch.aws_cloudwatch_dashboard.main | grep dashboard_name
```

O más fácil, verifica los outputs:
```bash
terraform output
```

**El nombre esperado es:** `genius-{environment}-application-status`
- Para **dev**: `genius-dev-application-status`
- Para **qa**: `genius-qa-application-status`
- Para **prod**: `genius-prod-application-status`

---

## ✅ Paso 3: Verificar la Región Correcta

**⚠️ IMPORTANTE:** Los dashboards de CloudWatch son **específicos de región**.

### 3.1 Verificar en qué región se creó el dashboard

En la carpeta de tu ambiente:

**En PowerShell:**
```powershell
Select-String -Path terraform.tfvars -Pattern aws_region
# O
Get-Content terraform.tfvars | Select-String aws_region
```

**En Bash/Linux:**
```bash
cat terraform.tfvars | grep aws_region
```

O verifica el provider:

**En PowerShell:**
```powershell
Select-String -Path provider.tf -Pattern region
```

**En Bash/Linux:**
```bash
cat provider.tf | grep region
```

**La región por defecto es:** `us-east-1` (US East - N. Virginia)

### 3.2 Verificar que estás en la región correcta en la consola de AWS

1. En la consola de AWS, mira la **esquina superior derecha**
2. Verifica que la región sea la misma donde desplegaste Terraform
3. Si es diferente, **cámbiala** usando el selector de región

**Ejemplo:**
- Si desplegaste en `us-east-1` → Debes estar en "US East (N. Virginia)"
- Si desplegaste en `us-west-2` → Debes estar en "US West (Oregon)"

✅ **Si estás en la región correcta**: Continúa al Paso 4
❌ **Si estás en otra región**: Cámbiala y busca de nuevo

---

## ✅ Paso 4: Buscar el Dashboard en CloudWatch

### 4.1 Búsqueda Directa por Nombre

En la consola de CloudWatch:
1. Ve a **CloudWatch** → **Panels** → **Dashboards**
2. En la pestaña **"Custom panels"**
3. Busca en el campo de búsqueda: `genius-dev-application-status` (reemplaza `dev` con tu ambiente)

### 4.2 Buscar Todas las Alarmas Primero

Si el dashboard no aparece, verifica si las **alarmas** existen:

1. En CloudWatch, ve a **Alarms** (en el menú izquierdo)
2. Busca las siguientes alarmas:
   - `genius-{environment}-unhealthy-hosts`
   - `genius-{environment}-http-5xx-errors`
   - `genius-{environment}-high-cpu`

✅ **Si las alarmas existen**: Los recursos se crearon, pero puede haber un problema con el dashboard específico
❌ **Si las alarmas NO existen**: Los recursos no se han desplegado, ve al Paso 6

### 4.3 Verificar usando la URL Directa

Copia esta URL y reemplaza `{region}` y `{environment}`:

```
https://console.aws.amazon.com/cloudwatch/home?region={region}#dashboards:name=genius-{environment}-application-status
```

**Ejemplo para dev en us-east-1:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status
```

**Si la URL funciona**: El dashboard existe, solo necesitabas la URL correcta
**Si dice "dashboard not found"**: El dashboard no existe, ve al Paso 6

---

## ✅ Paso 5: Verificar Permisos de IAM

Si las alarmas existen pero el dashboard no, puede ser un problema de permisos.

### 5.1 Verificar permisos necesarios

El usuario/rol que ejecutó Terraform necesita estos permisos:
- `cloudwatch:PutDashboard`
- `cloudwatch:GetDashboard`
- `cloudwatch:ListDashboards`
- `cloudwatch:DeleteDashboard`

### 5.2 Verificar errores en Terraform

Revisa si hubo errores al crear el dashboard:

```bash
terraform apply -refresh-only
```

O revisa los logs si usaste `-auto-approve`:
**En PowerShell:**
```powershell
terraform apply 2>&1 | Select-String -Pattern cloudwatch -CaseSensitive:$false
```

**En Bash/Linux:**
```bash
terraform apply 2>&1 | grep -i cloudwatch
```

---

## ✅ Paso 6: Crear/Actualizar el Dashboard

Si el dashboard no existe, necesitas crearlo o actualizarlo:

### 6.1 Opción A: Desplegar solo el módulo CloudWatch

```bash
cd infra/envs/dev  # o tu ambiente

# Verificar qué cambios se harán
terraform plan -target=module.cloudwatch

# Aplicar solo el módulo CloudWatch
terraform apply -target=module.cloudwatch
```

### 6.2 Opción B: Desplegar todo el ambiente

```bash
cd infra/envs/dev  # o tu ambiente

# Ver qué se creará/actualizará
terraform plan

# Aplicar todos los cambios
terraform apply
```

### 6.3 Verificar que se creó correctamente

Después de `terraform apply`, verifica:

```bash
terraform output
```

Deberías ver outputs relacionados con CloudWatch, o al menos el dashboard debería aparecer en:

**En PowerShell:**
```powershell
terraform state list | Select-String cloudwatch_dashboard
```

**En Bash/Linux:**
```bash
terraform state list | grep cloudwatch_dashboard
```

---

## 🔧 Solución Rápida: Agregar Outputs para Verificar

Si quieres verificar rápidamente el dashboard desde Terraform, agrega estos outputs a `infra/envs/dev/outputs.tf`:

```hcl
output "cloudwatch_dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = module.cloudwatch.dashboard_name
}

output "cloudwatch_dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = module.cloudwatch.dashboard_url
}
```

Luego ejecuta:
```bash
terraform refresh  # Actualizar el estado sin hacer cambios
terraform output   # Ver los outputs
```

Copia la URL del dashboard y ábrela en tu navegador.

---

## 📋 Checklist de Diagnóstico

Usa este checklist para identificar el problema:

- [ ] El módulo CloudWatch está en `main.tf`
- [ ] `terraform plan` muestra que el dashboard será creado o ya existe
- [ ] `terraform state list` muestra `aws_cloudwatch_dashboard.main`
- [ ] Estoy en la región correcta en la consola de AWS
- [ ] He buscado el dashboard por nombre exacto: `genius-{environment}-application-status`
- [ ] Las alarmas de CloudWatch existen (confirma que los recursos se crearon)
- [ ] He probado la URL directa del dashboard
- [ ] He ejecutado `terraform apply` después de configurar el módulo

---

## 🚨 Problemas Comunes y Soluciones

### Problema: "No veo nada en Dashboards"

**Causas posibles:**
1. ❌ El dashboard no se ha creado → Ejecuta `terraform apply`
2. ❌ Estás en la región incorrecta → Cambia la región en la consola
3. ❌ El nombre es diferente → Verifica con `terraform state show`

**Solución:**
**En PowerShell:**
```powershell
# Verificar estado
cd infra\envs\dev
terraform state list | Select-String cloudwatch

# Si no existe, crear
terraform apply -target=module.cloudwatch
```

**En Bash/Linux:**
```bash
# Verificar estado
cd infra/envs/dev
terraform state list | grep cloudwatch

# Si no existe, crear
terraform apply -target=module.cloudwatch
```

### Problema: "Las alarmas existen pero el dashboard no"

**Causa:** Error al crear el dashboard específicamente, pero las alarmas sí se crearon.

**Solución:**
```bash
# Intentar recrear solo el dashboard
terraform apply -target=module.cloudwatch.aws_cloudwatch_dashboard.main
```

### Problema: "Terraform dice que existe pero no lo veo en AWS"

**Causas posibles:**
1. Fue eliminado manualmente desde AWS Console
2. Cambió el nombre del proyecto/ambiente
3. Hay un problema de sincronización

**Solución:**
```bash
# Importar el recurso si fue eliminado
terraform import module.cloudwatch.aws_cloudwatch_dashboard.main genius-dev-application-status

# O recrearlo
terraform apply -target=module.cloudwatch.aws_cloudwatch_dashboard.main -replace=module.cloudwatch.aws_cloudwatch_dashboard.main
```

---

## 💡 Próximos Pasos

Una vez que identifiques el problema:

1. **Si el dashboard no existe:** Sigue el Paso 6 para crearlo
2. **Si existe pero no lo ves:** Verifica región y nombre exacto (Pasos 3 y 4)
3. **Si todo está bien pero sigue sin aparecer:** Verifica permisos (Paso 5)

Después de resolver el problema, el dashboard debería aparecer en:
- **CloudWatch** → **Panels** → **Dashboards** → **Custom panels**
