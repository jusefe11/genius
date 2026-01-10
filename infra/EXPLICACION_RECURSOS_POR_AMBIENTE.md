# 📊 Explicación: ¿Por qué varía la cantidad de recursos por ambiente?

Este documento explica las razones técnicas y de negocio por las cuales la cantidad de recursos AWS desplegados varía entre los diferentes ambientes (desarrollador, QA y producción).

---

## 📋 Resumen de Variación de Recursos

| Ambiente | Instancias EC2 | Oyentes ALB | Grupos de Seguridad | CloudWatch | Total Aprox. |
|----------|----------------|-------------|---------------------|------------|--------------|
| **Desarrollador** | 1-5 | 1-2 | 4-6 | 4 | ~29-34 recursos |
| **Control de Calidad (QA)** | 2-10 | 1-2 | 4-6 | 4 | ~34-39 recursos |
| **Producción** | 2-20 | 2 | 4-6 | 4 | ~39-49 recursos |

---

## 🔍 Factores que Causan la Variación

### 1. **Instancias EC2** (Mayor Variación)

**Razón Principal:** Diferentes configuraciones de Auto Scaling según las necesidades de cada ambiente.

#### Configuraciones por Ambiente:

| Ambiente | `min_size` | `desired_capacity` | `max_size` | Rango de Instancias |
|----------|------------|-------------------|------------|---------------------|
| **Dev** | 1 | 2 | 5 | **1-5 instancias** |
| **QA** | 2 | 2 | 10 | **2-10 instancias** |
| **Prod** | 2 | 3 | 20 | **2-20 instancias** |

**¿Por qué esta variación?**

1. **Desarrollador (1-5):**
   - **Mínimo costo:** Solo necesita una instancia para desarrollo y pruebas
   - **Alta disponibilidad limitada:** 2 instancias deseadas para pruebas básicas
   - **Máximo bajo:** 5 instancias suficientes para pruebas de carga
   - **Ubicación:** `infra/envs/dev/terraform.tfvars` líneas 49-51

2. **QA (2-10):**
   - **Mínimo más alto:** Necesita al menos 2 instancias para validar comportamiento multi-instancia
   - **Pruebas de escalado:** Máximo de 10 permite probar el auto scaling antes de producción
   - **Simula producción:** Configuración más cercana a producción para validar cambios
   - **Ubicación:** `infra/envs/qa/terraform.tfvars` líneas 49-51

3. **Producción (2-20):**
   - **Mínimo de 2:** Alta disponibilidad y redundancia en múltiples AZs
   - **Deseado 3:** Mayor capacidad base para manejar carga normal
   - **Máximo de 20:** Permite escalar según demanda real de usuarios
   - **Ubicación:** `infra/envs/prod/terraform.tfvars` líneas 49-51

**Recursos asociados por instancia:**
- Cada instancia EC2 requiere recursos adicionales implícitos (interfaces de red, volúmenes EBS, etc.)

---

### 2. **Oyentes ALB (Listeners)** (1-2)

**Razón Principal:** Depende de si está habilitado HTTPS/TLS.

#### Configuración Actual:

| Ambiente | `enable_https` | Oyentes Creados | Detalle |
|----------|----------------|-----------------|---------|
| **Dev** | `false` | **1** | Solo HTTP (puerto 80) |
| **QA** | `false` | **1** | Solo HTTP (puerto 80) |
| **Prod** | `false` | **1** | Actualmente HTTP, pero debería ser **2** (HTTP + HTTPS) |

**¿Cómo funciona?**

El módulo ALB (`infra/modules/alb/main.tf`) crea:

1. **Listener HTTP (siempre):** Puerto 80
   - Si `enable_https = true` → Redirige a HTTPS (301)
   - Si `enable_https = false` → Forward directo al Target Group

2. **Listener HTTPS (condicional):** Puerto 443
   - Solo se crea si `enable_https = true` Y `certificate_arn != ""`
   - Ver líneas 98-120 de `infra/modules/alb/main.tf`

**Recomendación:**
- **Producción debería tener 2 listeners** (HTTP + HTTPS) para seguridad
- **QA puede tener 1-2** dependiendo de si se prueban certificados
- **Dev puede tener 1** para simplificar

---

### 3. **Grupos de Seguridad** (4-6)

**Razón Principal:** Depende de características opcionales habilitadas.

#### Recursos Base (Siempre creados - 4 grupos):

1. **`alb-sg`** - Security Group para Application Load Balancer
2. **`web-sg`** - Alias de compatibilidad (mismo que alb-sg)
3. **`app-sg`** - Security Group para instancias de aplicación
4. **`db-sg`** - Security Group para bases de datos (preparado para futuro)

#### Recursos Opcionales (+1 o +2 grupos):

5. **`redis-sg`** - Solo si `enable_redis = true`
   - Para ElastiCache/Redis si se requiere cache
   - Ver `infra/modules/security_groups/main.tf` líneas 203-252

6. **`bastion-sg`** - Solo si `enable_ssh = true` Y `allowed_ssh_cidrs` no vacío
   - Para servidor bastion/jump host para acceso SSH
   - Ver `infra/modules/security_groups/main.tf` líneas 255-286

**Configuración Actual:**
- Todos los ambientes tienen `enable_redis = false` (comentado)
- Todos los ambientes tienen `enable_ssh = false` (comentado)
- Por lo tanto: **4 grupos de seguridad** en todos los ambientes actualmente

**Variación posible (4-6):**
- **4 grupos:** Configuración mínima actual (dev, qa, prod)
- **5 grupos:** Si se habilita Redis O SSH (pero no ambos)
- **6 grupos:** Si se habilitan tanto Redis como SSH

---

### 4. **Recursos CloudWatch** (Constante: 4)

**Razón Principal:** Configuración idéntica en todos los ambientes.

Los recursos de CloudWatch son **constantes** independientemente del ambiente:

1. **Alarma 1:** `unhealthy_hosts` - Instancias no saludables
2. **Alarma 2:** `http_5xx_errors` - Errores 5xx del servidor
3. **Alarma 3:** `high_cpu` - CPU por encima del umbral (80%)
4. **Dashboard:** `application-status` - Dashboard de monitoreo

**Ubicación:** `infra/modules/cloudwatch/main.tf`

**Nota:** Aunque la cantidad de recursos es constante, las métricas y umbrales son los mismos, pero las alertas se disparan según las condiciones específicas de cada ambiente.

---

## 📊 Desglose Detallado de Recursos por Categoría

### Recursos Base (Comunes a Todos los Ambientes)

#### Red y Conectividad (~17 recursos):
- 1 VPC
- 1 Internet Gateway
- 2 Subredes Públicas
- 2 Subredes Privadas
- 2 Elastic IPs
- 2 NAT Gateways
- 1 Route Table Pública
- 2 Route Tables Privadas
- 4 Route Table Associations (2 públicas + 2 privadas)

#### Load Balancer Base (~2 recursos):
- 1 Application Load Balancer (ALB)
- 1 Target Group

#### Auto Scaling Base (~3 recursos):
- 1 Launch Template
- 1 Auto Scaling Group
- 2 Políticas de Auto Scaling (scale-up, scale-down)

#### Seguridad Base (4 recursos):
- 4 Security Groups (alb, web, app, db)

#### CloudWatch (4 recursos):
- 3 Alarmas
- 1 Dashboard

#### Data Sources (1 recurso):
- 1 Data Source para AMI (si `ami_id = ""`)

**Total Base:** ~31 recursos

---

### Recursos Variables por Ambiente

#### 1. Instancias EC2 (Variables):
- **Dev:** 1-5 instancias según auto scaling
- **QA:** 2-10 instancias según auto scaling
- **Prod:** 2-20 instancias según auto scaling

#### 2. Oyentes ALB (Variables):
- **Dev/QA:** 1 listener (HTTP)
- **Prod (recomendado):** 2 listeners (HTTP + HTTPS)

#### 3. Security Groups Opcionales (Variables):
- **Base:** 4 grupos
- **Con Redis:** +1 grupo (5 total)
- **Con SSH/Bastion:** +1 grupo (5 total)
- **Con ambos:** +2 grupos (6 total)

---

## 💡 Recomendaciones por Ambiente

### Desarrollo (Dev)
- ✅ **Configuración actual es adecuada**
- ✅ Mantener `max_size = 5` (suficiente para pruebas)
- ✅ HTTPS opcional (puede mantenerse en HTTP)
- ❌ No requiere Redis ni Bastion en la mayoría de casos

### Control de Calidad (QA)
- ✅ **Configuración actual es adecuada**
- ✅ `max_size = 10` permite probar escalado
- 💡 Considerar habilitar HTTPS para probar certificados
- 💡 Considerar habilitar Redis si la app lo usa

### Producción (Prod)
- ⚠️ **CRÍTICO:** Habilitar HTTPS (`enable_https = true`)
- ✅ `max_size = 20` adecuado para alta demanda
- ✅ Mínimo de 2 instancias para alta disponibilidad
- 💡 Considerar habilitar Redis si mejora rendimiento
- 💡 Considerar Bastion Host para acceso seguro si es necesario

---

## 🔧 Cómo Modificar la Cantidad de Recursos

### Cambiar cantidad de instancias EC2:

**Archivo:** `infra/envs/{ambiente}/terraform.tfvars`

```hcl
# Ejemplo para aumentar capacidad en producción
min_size         = 3
desired_capacity = 5
max_size         = 30
```

### Habilitar HTTPS (aumenta listeners de 1 a 2):

**Archivo:** `infra/envs/{ambiente}/terraform.tfvars`

```hcl
enable_https = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
```

### Habilitar Redis (aumenta security groups de 4 a 5):

**Archivo:** `infra/envs/{ambiente}/terraform.tfvars`

```hcl
enable_redis = true
```

### Habilitar SSH/Bastion (aumenta security groups de 4 a 5):

**Archivo:** `infra/envs/{ambiente}/terraform.tfvars`

```hcl
enable_ssh = true
allowed_ssh_cidrs = ["203.0.113.0/24"]  # Tu IP o rango de IPs
```

---

## 📈 Cálculo del Total Aproximado de Recursos

### Fórmula:
```
Total = Recursos Base (~31) 
      + Instancias EC2 (1-20 según ambiente)
      + Oyentes ALB adicionales (0-1 según HTTPS)
      + Security Groups opcionales (0-2 según Redis/SSH)
```

### Ejemplos:

**Desarrollador:**
```
31 (base) + 2 (instancias deseadas) + 0 (solo HTTP) + 0 (sin opcionales)
= ~33 recursos
```
*Nota: El rango 29-34 incluye variación por auto scaling y recursos adicionales*

**QA:**
```
31 (base) + 2 (instancias deseadas) + 0 (solo HTTP) + 0 (sin opcionales)
= ~33 recursos (base), puede subir a ~39 con auto scaling a 10
```

**Producción:**
```
31 (base) + 3 (instancias deseadas) + 1 (HTTPS recomendado) + 0-2 (opcionales)
= ~35-49 recursos según configuración
```

---

## 📝 Notas Finales

1. **Los recursos son dinámicos:** Las instancias EC2 varían según auto scaling
2. **Configuración flexible:** Cada ambiente puede ajustarse según necesidades
3. **Costo vs. Funcionalidad:** Dev minimiza costo, Prod maximiza disponibilidad
4. **Seguridad progresiva:** Prod requiere más recursos de seguridad (HTTPS, etc.)
5. **Escalabilidad:** Prod debe soportar mayor carga, por eso más instancias máximas

---

**Última actualización:** Generado desde la configuración actual de Terraform
**Archivos relacionados:**
- `infra/envs/{dev,qa,prod}/terraform.tfvars`
- `infra/modules/alb/main.tf`
- `infra/modules/autoscaling/main.tf`
- `infra/modules/security_groups/main.tf`
- `infra/modules/cloudwatch/main.tf`
