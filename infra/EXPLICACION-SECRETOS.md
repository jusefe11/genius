# ¿Por qué sigue pasando el error de secretos eliminados?

## 🔍 Causa Raíz del Problema

### El Problema Principal

Los **provisioners `destroy-time`** en Terraform **solo se ejecutan** cuando:
1. ✅ El recurso **está en el estado de Terraform**
2. ✅ Ejecutas `terraform destroy` sobre ese recurso específico

### ¿Cuándo NO se ejecutan los provisioners?

Los provisioners **NO se ejecutan** cuando:
1. ❌ Los secretos fueron eliminados **fuera de Terraform** (manualmente, por otro proceso, etc.)
2. ❌ Los secretos fueron eliminados en un `terraform destroy` **anterior** y ya no están en el estado
3. ❌ Ejecutas `terraform apply` **sin haber ejecutado destroy primero**

## 📊 Flujo del Problema

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Ejecutas terraform destroy                               │
│    → Los secretos se eliminan con período de recuperación   │
│    → Los provisioners se ejecutan y eliminan inmediatamente │
│    ✅ TODO BIEN                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Ejecutas terraform apply                                 │
│    → Los secretos ya no existen                             │
│    → Terraform los crea sin problemas                       │
│    ✅ TODO BIEN                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Algo elimina los secretos (manual, error, etc.)         │
│    → Los secretos quedan en período de recuperación        │
│    → Terraform NO los conoce (no están en el estado)       │
│    ❌ PROBLEMA                                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Ejecutas terraform apply                                 │
│    → Terraform intenta crear los secretos                   │
│    → AWS dice: "Ya existe pero está eliminado"             │
│    ❌ ERROR: "already scheduled for deletion"              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Por Qué los Provisioners No Ayudan Aquí

Los provisioners están configurados así:

```hcl
provisioner "local-exec" {
  when    = destroy
  command = "aws secretsmanager delete-secret --secret-id ${self.name} --force-delete-without-recovery"
}
```

**Problema:** Este provisioner solo se ejecuta cuando:
- El recurso está en el estado de Terraform
- Ejecutas `terraform destroy` sobre ese recurso

**Si el secreto ya fue eliminado previamente:**
- No está en el estado de Terraform
- El provisioner nunca se ejecuta
- El secreto queda en período de recuperación
- `terraform apply` falla

## ✅ Soluciones

### Solución 1: Script de Limpieza (Actual)

**Antes de cada `terraform apply`:**
```powershell
cd infra
.\limpiar-secretos-antes-apply.ps1
cd envs\dev
terraform apply
```

**Ventajas:**
- ✅ Funciona siempre
- ✅ Limpia secretos eliminados previamente
- ✅ No depende del estado de Terraform

**Desventajas:**
- ❌ Requiere ejecutar manualmente antes de cada apply
- ❌ Fácil de olvidar

### Solución 2: Script Seguro (Recomendado)

**Usar el script que hace todo automáticamente:**
```powershell
cd infra
.\terraform-apply-seguro.ps1
```

**Ventajas:**
- ✅ Automático
- ✅ No te olvidas de limpiar
- ✅ Funciona siempre

### Solución 3: Cambiar recovery_window_in_days a 0

**Modificar el módulo para que los secretos se eliminen inmediatamente:**

```hcl
recovery_window_in_days = 0  # Eliminación inmediata
```

**Ventajas:**
- ✅ Los secretos se eliminan inmediatamente
- ✅ No hay período de recuperación

**Desventajas:**
- ❌ **PELIGROSO**: No puedes recuperar secretos eliminados accidentalmente
- ❌ No recomendado para producción

## 🎓 Conclusión

**El error sigue pasando porque:**
1. Los secretos fueron eliminados fuera del control de Terraform
2. Los provisioners solo funcionan durante `terraform destroy`
3. Cuando ejecutas `terraform apply`, Terraform no sabe que los secretos están eliminados
4. AWS no permite crear secretos con nombres que están en período de recuperación

**La solución es:**
- ✅ Usar `.\limpiar-secretos-antes-apply.ps1` antes de cada apply
- ✅ O usar `.\terraform-apply-seguro.ps1` que lo hace automáticamente
- ✅ Los provisioners ayudan durante destroy, pero no resuelven el problema si los secretos ya fueron eliminados

## 💡 Recomendación Final

**Para desarrollo:**
```powershell
cd infra
.\terraform-apply-seguro.ps1  # Siempre usa este script
```

**Para producción:**
- Mantén el período de recuperación (30 días)
- Usa el script de limpieza solo cuando sea necesario
- Considera usar `terraform import` si los secretos ya existen
