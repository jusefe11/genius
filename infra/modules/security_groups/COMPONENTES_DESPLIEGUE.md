# Componentes Desplegados - Módulo Security Groups

## Tabla de Componentes

| Nombre del Componente | ¿Qué hace? |
|----------------------|------------|
| **ALB Security Group** | Permite que el balanceador reciba tráfico HTTP/HTTPS desde Internet y envíe tráfico a los servidores de aplicación |
| **Web Security Group** | Igual que ALB Security Group, creado para compatibilidad con código antiguo |
| **App Security Group** | Protege los servidores de aplicación. Solo permite tráfico desde el balanceador, no desde Internet directamente (seguridad en capas) |
| **Database Security Group** | Protege la base de datos. Solo permite conexiones desde los servidores de aplicación, nunca desde Internet |
| **Redis Security Group** | Protege el servidor de caché Redis. Solo permite conexiones desde los servidores de aplicación. Se crea solo si `enable_redis = true` |
| **Bastion Security Group** | Permite acceso SSH seguro desde IPs específicas (como tu oficina) para administrar otros servidores. Se crea solo si `enable_ssh = true` |

---

## Resumen Simple

### Componentes que SIEMPRE se crean (4):

1. **ALB Security Group** → Para el balanceador de carga
2. **Web Security Group** → Para compatibilidad (igual que ALB)
3. **App Security Group** → Para los servidores donde corre tu aplicación
4. **Database Security Group** → Para la base de datos

### Componentes OPCIONALES (2):

5. **Redis Security Group** → Solo si necesitas caché Redis (`enable_redis = true`)
6. **Bastion Security Group** → Solo si necesitas acceso SSH (`enable_ssh = true`)

**Total mínimo**: 4 Security Groups  
**Total máximo**: 6 Security Groups

---

## ¿Cómo están configurados?

### 1. ALB Security Group

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto 80 (HTTP) desde Internet (cualquier IP por defecto: `0.0.0.0/0`)
- ✅ Puerto 443 (HTTPS) desde Internet (cualquier IP por defecto: `0.0.0.0/0`)
- ⚠️ Puerto 22 (SSH) desde IPs específicas (solo si `enable_ssh = true`)

**Reglas de SALIDA (Egress):**
- ✅ Todo el tráfico saliente permitido (puede responder a usuarios y conectarse a otros servicios)

**¿Por qué esta configuración?** El balanceador necesita recibir tráfico web desde Internet y poder responder o conectarse a los servidores de aplicación.

---

### 2. Web Security Group

**Configuración:** Exactamente igual que ALB Security Group

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto 80 (HTTP) desde Internet
- ✅ Puerto 443 (HTTPS) desde Internet
- ⚠️ Puerto 22 (SSH) desde IPs específicas (solo si `enable_ssh = true`)

**Reglas de SALIDA (Egress):**
- ✅ Todo el tráfico saliente permitido

**¿Por qué existe?** Es un alias creado para mantener compatibilidad con código antiguo que podría estar usando este nombre.

---

### 3. App Security Group ⚠️ **MÁS IMPORTANTE**

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto de aplicación (default: 8080) **SOLO desde ALB Security Group** - Esto es clave: nadie desde Internet puede atacar directamente estos servidores
- ⚠️ Puerto 22 (SSH) desde IPs específicas (solo si `enable_ssh = true`)
- ✅ Puerto de aplicación desde sí mismo (`self = true`) - Permite que los servidores de app se comuniquen entre sí

**Reglas de SALIDA (Egress):**
- ✅ Todo el tráfico saliente permitido (para llamar APIs, descargar actualizaciones, etc.)

**¿Por qué esta configuración?** Implementa el principio de "mínimo acceso necesario". Los servidores de aplicación están completamente protegidos de Internet - solo el balanceador puede comunicarse con ellos. Esto es seguridad en capas.

---

### 4. Database Security Group

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto de base de datos (default: 3306 para MySQL) **SOLO desde App Security Group** - Solo los servidores de aplicación pueden acceder
- ✅ Puerto de BD desde sí mismo (`self = true`) - Para replicación entre servidores de base de datos

**Reglas de SALIDA (Egress):**
- ✅ Solo hacia App Security Group y sí mismo - Limitado para replicación y backups

**¿Por qué esta configuración?** La base de datos está completamente aislada. Internet nunca puede acceder directamente, solo los servidores de aplicación pueden consultarla. Esto protege tus datos críticos.

---

### 5. Redis Security Group (Opcional)

**¿Cuándo se crea?** Solo si `enable_redis = true`

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto 6379 (Redis estándar) **SOLO desde App Security Group**
- ✅ Puerto 6379 desde sí mismo (`self = true`) - Para comunicación entre nodos Redis
- ✅ Puerto 16379 (Redis Cluster) **SOLO desde App Security Group** - Para configuraciones avanzadas

**Reglas de SALIDA (Egress):**
- ✅ Todo el tráfico saliente permitido

**¿Por qué esta configuración?** El caché Redis solo debe ser accesible desde la aplicación, nunca desde Internet.

---

### 6. Bastion Security Group (Opcional)

**¿Cuándo se crea?** Solo si `enable_ssh = true`

**Reglas de ENTRADA (Ingress):**
- ✅ Puerto 22 (SSH) **SOLO desde IPs específicas** que definas en `allowed_ssh_cidrs` (ej: la IP de tu oficina)

**Reglas de SALIDA (Egress):**
- ✅ Todo el tráfico saliente permitido - Para que puedas conectarte desde el bastion a otros servidores

**¿Por qué esta configuración?** El bastion es un servidor "saltador" seguro. Solo tú (desde tu IP) puedes conectarte por SSH, y desde ahí puedes administrar otros servidores de forma segura.

---

## Resumen de Seguridad

| Componente | ¿Puede recibir tráfico de Internet? | ¿Quién puede acceder? |
|------------|-------------------------------------|----------------------|
| **ALB** | ✅ Sí (HTTP/HTTPS) | Cualquiera desde Internet |
| **Web** | ✅ Sí (HTTP/HTTPS) | Cualquiera desde Internet |
| **App** | ❌ No | Solo el balanceador (ALB) |
| **Database** | ❌ No | Solo los servidores de aplicación |
| **Redis** | ❌ No | Solo los servidores de aplicación |
| **Bastion** | ⚠️ Solo SSH desde IPs específicas | Solo desde IPs que tú definas |

**Principio aplicado:** Seguridad en capas - cada componente solo recibe el tráfico absolutamente necesario.
