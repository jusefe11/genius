# 🔧 Guía: Cómo Igualar la Cantidad de Recursos en Todos los Ambientes

Esta guía explica cómo hacer que todos los ambientes (dev, QA, prod) desplieguen exactamente la misma cantidad de recursos.

---

## 📊 Diferencias Actuales que Causan Variación

### 1. **Auto Scaling Group** (Diferente en cada ambiente)

| Ambiente | `min_size` | `desired_capacity` | `max_size` | Resultado |
|----------|------------|-------------------|------------|-----------|
| **Dev** | 1 | 2 | 5 | 1-5 instancias |
| **QA** | 2 | 2 | 10 | 2-10 instancias |
| **Prod** | 2 | 3 | 20 | 2-20 instancias |

**🔴 Esta es la principal causa de variación**

### 2. **Health Check Path** (Diferente)

| Ambiente | `health_check_path` |
|----------|---------------------|
| **Dev** | `/` |
| **QA** | `/` |
| **Prod** | `/health` |

**⚠️ Nota:** Esta diferencia no afecta la cantidad de recursos, solo la configuración.

### 3. **HTTPS (Listeners ALB)** (Igual en todos actualmente)

| Ambiente | `enable_https` | Listeners |
|----------|----------------|-----------|
| **Dev** | `false` | 1 (HTTP) |
| **QA** | `false` | 1 (HTTP) |
| **Prod** | `false` | 1 (HTTP) |

✅ **Ya están iguales**

### 4. **Security Groups Opcionales** (Igual en todos actualmente)

| Ambiente | `enable_redis` | `enable_ssh` | Security Groups |
|----------|----------------|--------------|-----------------|
| **Dev** | `false` | `false` | 4 |
| **QA** | `false` | `false` | 4 |
| **Prod** | `false` | `false` | 4 |

✅ **Ya están iguales**

---

## 🎯 Opciones para Igualar Recursos

### **Opción 1: Igualar a Valores Intermedios (Recomendada)**

Igualar todos los ambientes a valores que funcionen bien para cualquier ambiente.

**Configuración propuesta:**
```hcl
min_size         = 2
desired_capacity = 2
max_size         = 5
```

**Ventajas:**
- ✅ Balance entre costo y funcionalidad
- ✅ Suficiente para desarrollo y pruebas
- ✅ Permite validar auto scaling en QA
- ✅ No es excesivo para producción si es pequeño

**Desventajas:**
- ⚠️ Producción podría necesitar más instancias bajo alta carga
- ⚠️ Máximo de 5 puede ser limitante para QA si se requiere probar escalado extremo

---

### **Opción 2: Igualar al Mínimo (Dev)**

Igualar todo al mínimo actual (desarrollo).

**Configuración propuesta:**
```hcl
min_size         = 1
desired_capacity = 2
max_size         = 5
```

**Ventajas:**
- ✅ Minimiza costos
- ✅ Adecuado para desarrollo/pruebas

**Desventajas:**
- ⚠️ Producción con solo 1 instancia mínima reduce alta disponibilidad
- ⚠️ No permite probar comportamiento multi-instancia en QA de forma consistente

---

### **Opción 3: Igualar a Configuración de Producción**

Igualar todo a los valores de producción.

**Configuración propuesta:**
```hcl
min_size         = 2
desired_capacity = 3
max_size         = 20
```

**Ventajas:**
- ✅ Alta disponibilidad garantizada en todos los ambientes
- ✅ Permite pruebas de escalado realistas en QA
- ✅ Producción ya está optimizada

**Desventajas:**
- ❌ Mayor costo (especialmente en Dev)
- ❌ Desperdicio de recursos en desarrollo
- ❌ Mayor complejidad para desarrollo local

---

### **Opción 4: Valores Conservadores Equilibrados**

Configuración equilibrada que funciona bien para todos.

**Configuración propuesta:**
```hcl
min_size         = 2
desired_capacity = 2
max_size         = 10
```

**Ventajas:**
- ✅ Alta disponibilidad (mínimo 2)
- ✅ Suficiente para pruebas de escalado en QA
- ✅ No excesivo para desarrollo
- ✅ Máximo de 10 permite validar auto scaling

**Desventajas:**
- ⚠️ Puede ser más de lo necesario en Dev (costo)
- ⚠️ Puede ser menos de lo necesario en Prod bajo alta carga

---

## 💡 Recomendación Final

### **Recomiendo la Opción 1: Valores Intermedios**

```hcl
# Para TODOS los ambientes (dev, qa, prod)
min_size         = 2
desired_capacity = 2
max_size         = 5
```

**Justificación:**
1. ✅ **Alta disponibilidad:** Mínimo de 2 instancias en todos los ambientes
2. ✅ **Costo controlado:** Máximo de 5 evita escalado excesivo
3. ✅ **Suficiente para pruebas:** Permite validar comportamiento multi-instancia
4. ✅ **Uniformidad:** Facilita comparación entre ambientes
5. ✅ **Flexibilidad:** Si producción necesita más, se puede ajustar después

---

## 🔧 Implementación Paso a Paso

### Paso 1: Actualizar Dev

**Archivo:** `infra/envs/dev/terraform.tfvars`

```hcl
# Cambiar de:
min_size         = 1
desired_capacity = 2
max_size         = 5

# A:
min_size         = 2  # Cambiado de 1 a 2
desired_capacity = 2  # Ya está igual
max_size         = 5  # Ya está igual
```

### Paso 2: Actualizar QA

**Archivo:** `infra/envs/qa/terraform.tfvars`

```hcl
# Cambiar de:
min_size         = 2
desired_capacity = 2
max_size         = 10

# A:
min_size         = 2  # Ya está igual
desired_capacity = 2  # Ya está igual
max_size         = 5  # Cambiado de 10 a 5
```

### Paso 3: Actualizar Prod

**Archivo:** `infra/envs/prod/terraform.tfvars`

```hcl
# Cambiar de:
min_size         = 2
desired_capacity = 3
max_size         = 20

# A:
min_size         = 2  # Ya está igual
desired_capacity = 2  # Cambiado de 3 a 2
max_size         = 5  # Cambiado de 20 a 5
```

---

## ⚠️ Consideraciones Importantes

### Antes de Igualar:

1. **Evaluar impacto en producción:**
   - ¿El tráfico actual requiere más de 5 instancias?
   - ¿Se han visto picos que requieran escalado a 10+ instancias?
   - Si la respuesta es SÍ, considera mantener prod con valores más altos

2. **Costo vs. Uniformidad:**
   - Igualar a valores altos (prod) = Mayor costo
   - Igualar a valores bajos (dev) = Menor disponibilidad en prod
   - Valor intermedio = Balance

3. **Auto Scaling:**
   - Recuerda que el `max_size` es un límite máximo
   - El auto scaling puede crear instancias entre `min_size` y `max_size`
   - Si necesitas más instancias temporalmente, puedes aumentar `max_size`

### Después de Igualar:

1. **Aplicar cambios con Terraform:**
   ```bash
   cd infra/envs/dev
   terraform plan  # Revisar cambios
   terraform apply # Aplicar cambios
   
   cd ../qa
   terraform plan
   terraform apply
   
   cd ../prod
   terraform plan
   terraform apply
   ```

2. **Monitorear:**
   - Verificar que todas las instancias estén saludables
   - Monitorear métricas de CloudWatch
   - Validar que el auto scaling funcione correctamente

---

## 📈 Resultado Esperado

### Antes (Diferente):
- **Dev:** 1-5 instancias (~33 recursos)
- **QA:** 2-10 instancias (~34-39 recursos)
- **Prod:** 2-20 instancias (~35-49 recursos)

### Después (Igual):
- **Dev:** 2-5 instancias (~34 recursos)
- **QA:** 2-5 instancias (~34 recursos)
- **Prod:** 2-5 instancias (~34 recursos)

**Total aproximado:** ~34 recursos en todos los ambientes

---

## 🔄 Si Necesitas Ajustar Más Tarde

Si después de igualar necesitas ajustar producción por demanda:

**Opción A: Mantener igual y escalar manualmente**
- Aumentar temporalmente `desired_capacity` cuando sea necesario
- Volver a valores base después

**Opción B: Permitir variación solo en max_size**
- Mantener `min_size` y `desired_capacity` iguales
- Permitir `max_size` diferente solo en prod (ej: prod max=20, otros max=5)

**Opción C: Usar variables de entorno en Terraform Cloud/Enterprise**
- Centralizar valores comunes
- Permitir override por ambiente solo cuando sea necesario

---

## ✅ Checklist de Implementación

- [ ] Decidir qué valores usar (recomendado: Opción 1)
- [ ] Actualizar `infra/envs/dev/terraform.tfvars`
- [ ] Actualizar `infra/envs/qa/terraform.tfvars`
- [ ] Actualizar `infra/envs/prod/terraform.tfvars`
- [ ] Ejecutar `terraform plan` en cada ambiente
- [ ] Revisar los cambios planeados
- [ ] Aplicar cambios con `terraform apply`
- [ ] Verificar que todos los ambientes tengan la misma cantidad de recursos
- [ ] Documentar los cambios realizados
- [ ] Notificar al equipo sobre los cambios

---

**¿Listo para implementar?** Sigue los pasos de implementación arriba según la opción elegida.
