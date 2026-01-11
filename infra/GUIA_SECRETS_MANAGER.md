# 🔐 Guía de Uso de AWS Secrets Manager

Esta guía explica cómo usar AWS Secrets Manager para almacenar y gestionar secretos de forma segura en la infraestructura.

---

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Arquitectura](#arquitectura)
3. [Tipos de Secretos Soportados](#tipos-de-secretos-soportados)
4. [Configuración](#configuración)
5. [Ejemplos de Uso](#ejemplos-de-uso)
6. [Acceso a Secretos en las Instancias](#acceso-a-secretos-en-las-instancias)
7. [Seguridad](#seguridad)
8. [Costos](#costos)

---

## 🎯 Introducción

AWS Secrets Manager permite almacenar, rotar y gestionar secretos como credenciales de base de datos, API keys, y otros valores sensibles de forma segura.

### Beneficios:

- ✅ **Gestión centralizada** de secretos
- ✅ **Cifrado automático** con AWS KMS
- ✅ **Rotación automática** de credenciales (configurable)
- ✅ **Auditoría integrada** con CloudTrail
- ✅ **Integración con IAM** para control de acceso granular

---

## 🏗️ Arquitectura

La integración de Secrets Manager en esta infraestructura incluye:

1. **Módulo de Secrets Manager** (`infra/modules/secrets-manager/`)
   - Crea y gestiona secretos en AWS Secrets Manager
   - Soporta múltiples tipos de secretos

2. **Permisos IAM** (configurados automáticamente)
   - Las instancias EC2 tienen permisos para leer secretos
   - Solo pueden leer secretos específicos del proyecto/ambiente

3. **User Data Script** (actualizado automáticamente)
   - Lee secretos al iniciar las instancias
   - Guarda secretos en `/opt/app/secrets/` con permisos restrictivos

---

## 📦 Tipos de Secretos Soportados

### 1. Secreto de Base de Datos (`database/credentials`)

Almacena credenciales completas de base de datos:
- Usuario (`username`)
- Contraseña (`password`)
- Host (`host`)
- Puerto (`port`)
- Nombre de base de datos (`database`)
- Motor (`engine`: mysql, postgres, mongodb, etc.)

### 2. Secreto de API Keys (`app/api-keys`)

Almacena múltiples API keys en un solo secreto:
- Clave-valor flexible
- Útil para servicios externos (APIs de terceros, tokens, etc.)

### 3. Secretos Genéricos (`app/*`)

Permite crear secretos personalizados con contenido arbitrario:
- Descripción opcional
- Contenido personalizado (JSON, texto plano, etc.)

---

## ⚙️ Configuración

### Paso 1: Configurar Variables en `terraform.tfvars`

#### Ejemplo: Crear Secreto de Base de Datos

```hcl
# Habilitar creación del secreto de BD
create_db_secret = true

# Credenciales de base de datos (valores sensibles)
db_username = "myapp_user"
db_password = "SuperSecurePassword123!"
db_host     = "mydb.example.com"
db_port     = 3306
db_name     = "myapp_db"
db_engine   = "mysql"
```

#### Ejemplo: Crear Secreto de API Keys

```hcl
# Habilitar creación del secreto de API Keys
create_api_keys_secret = true

# API Keys (valores sensibles)
api_keys = {
  stripe_api_key      = "sk_live_xxxxxxxxxxxxx"
  sendgrid_api_key    = "SG.xxxxxxxxxxxxx"
  external_service_token = "Bearer xxxxxxxxxxxxx"
}
```

#### Ejemplo: Crear Secretos Genéricos

```hcl
# Secretos genéricos personalizados
app_secrets = {
  jwt_secret = {
    description   = "JWT signing secret for authentication"
    secret_string = jsonencode({
      secret = "my-jwt-secret-key-12345"
      algorithm = "HS256"
    })
  }
  
  encryption_key = {
    description   = "Encryption key for sensitive data"
    secret_string = "aes256-encryption-key-here"
  }
}
```

#### Ejemplo: Usar Clave KMS Personalizada (Opcional)

```hcl
# Si necesitas usar una clave KMS personalizada para cifrar secretos
secrets_manager_kms_key_ids = [
  "arn:aws:kms:us-east-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
]
```

**Nota:** Si no especificas `secrets_manager_kms_key_ids`, AWS Secrets Manager usará la clave KMS por defecto del servicio.

---

### Paso 2: Aplicar Cambios con Terraform

```bash
# Navegar al ambiente deseado
cd infra/envs/dev  # o qa, prod

# Inicializar Terraform (si es necesario)
terraform init

# Planear cambios
terraform plan

# Aplicar cambios
terraform apply
```

---

## 💡 Ejemplos de Uso

### Ejemplo Completo: Configuración para Producción

```hcl
# infra/envs/prod/terraform.tfvars

# ... otras configuraciones ...

# Secrets Manager - Base de Datos
create_db_secret = true
db_username      = "prod_app_user"
db_password      = var.db_password  # Usar variable de entorno o Terraform Cloud
db_host          = "prod-db.cluster-xxxxx.us-east-1.rds.amazonaws.com"
db_port          = 3306
db_name          = "production_db"
db_engine        = "mysql"

# Secrets Manager - API Keys
create_api_keys_secret = true
api_keys = {
  payment_gateway_api_key = var.payment_api_key
  email_service_api_key   = var.email_api_key
  monitoring_api_key      = var.monitoring_api_key
}

# Secrets Manager - Secretos Genéricos
app_secrets = {
  session_secret = {
    description   = "Session encryption secret"
    secret_string = var.session_secret
  }
}

# Clave KMS personalizada para producción (recomendado)
secrets_manager_kms_key_ids = [
  "arn:aws:kms:us-east-1:123456789012:key/production-secrets-key"
]
```

### Ejemplo: Solo Secretos Genéricos (Sin BD)

```hcl
# infra/envs/dev/terraform.tfvars

# No crear secreto de BD
create_db_secret = false

# No crear secreto de API Keys
create_api_keys_secret = false

# Solo secretos genéricos
app_secrets = {
  app_config = {
    description   = "Application configuration"
    secret_string = jsonencode({
      feature_flag_a = true
      feature_flag_b = false
      api_timeout = 30
    })
  }
}
```

---

## 🖥️ Acceso a Secretos en las Instancias

### Ubicación de los Secretos

Los secretos se almacenan automáticamente en las instancias EC2 en:

```
/opt/app/secrets/
├── genius-dev-database-credentials.json  # Secreto de BD (JSON)
├── db.env                                 # Variables de entorno extraídas de BD
├── genius-dev-app-api-keys.json          # Secreto de API Keys (JSON)
├── api-keys.env                           # Variables de entorno extraídas de API Keys
└── genius-dev-app-<nombre>.json          # Secretos genéricos
```

### Formato de Archivos

#### Archivos JSON
Contienen el secreto completo en formato JSON:

```json
{
  "username": "myapp_user",
  "password": "SuperSecurePassword123!",
  "host": "mydb.example.com",
  "port": 3306,
  "database": "myapp_db",
  "engine": "mysql"
}
```

#### Archivos .env
Variables de entorno extraídas automáticamente para BD y API Keys:

```bash
# db.env
USERNAME=myapp_user
PASSWORD=SuperSecurePassword123!
HOST=mydb.example.com
PORT=3306
DATABASE=myapp_db
ENGINE=mysql

# api-keys.env
STRIPE_API_KEY=sk_live_xxxxxxxxxxxxx
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
EXTERNAL_SERVICE_TOKEN=Bearer xxxxxxxxxxxxx
```

### Uso en Aplicaciones

#### Opción 1: Cargar Variables de Entorno (Recomendado)

```bash
# En tu script de inicio de aplicación
source /opt/app/secrets/db.env
source /opt/app/secrets/api-keys.env

# Tu aplicación ahora tiene acceso a las variables
# Ejemplo: $USERNAME, $PASSWORD, $STRIPE_API_KEY, etc.
```

#### Opción 2: Leer JSON Directamente

```python
# Python ejemplo
import json
import os

with open('/opt/app/secrets/genius-dev-database-credentials.json', 'r') as f:
    db_config = json.load(f)

username = db_config['username']
password = db_config['password']
```

```javascript
// Node.js ejemplo
const fs = require('fs');
const dbConfig = JSON.parse(
  fs.readFileSync('/opt/app/secrets/genius-dev-database-credentials.json', 'utf8')
);

const username = dbConfig.username;
const password = dbConfig.password;
```

#### Opción 3: Usar con Docker

```bash
# En user_data o script de despliegue
docker run -d \
  --name app \
  --env-file /opt/app/secrets/db.env \
  --env-file /opt/app/secrets/api-keys.env \
  myapp:latest
```

---

## 🔒 Seguridad

### Permisos IAM

Las instancias EC2 tienen permisos IAM limitados:

- ✅ **Permitido:** Leer secretos específicos del proyecto/ambiente
- ✅ **Permitido:** Desencriptar con KMS (usando la clave configurada)
- ❌ **Denegado:** Crear, modificar o eliminar secretos
- ❌ **Denegado:** Leer secretos de otros proyectos/ambientes

### Permisos de Archivos

Los archivos de secretos tienen permisos restrictivos:

```bash
# Propietario: root
# Permisos: 600 (solo lectura para root)
chmod 600 /opt/app/secrets/*
```

### Rotación de Secretos

**Nota:** La rotación automática de secretos no está habilitada por defecto. Para habilitarla:

1. Configurar rotación en AWS Secrets Manager (consola o CLI)
2. Crear una función Lambda para rotar credenciales
3. Programar rotación automática (cada 30, 60, o 90 días)

---

## 💰 Costos

AWS Secrets Manager tiene un costo basado en:

1. **$0.40 por secreto por mes** - Almacenamiento
2. **$0.05 por 10,000 llamadas API** - Lectura de secretos

### Estimación de Costos

| Ambiente | Secretos | Costo Mensual (Aprox.) |
|----------|----------|------------------------|
| Dev      | 2-3      | $0.80 - $1.20         |
| QA       | 2-3      | $0.80 - $1.20         |
| Prod     | 3-5      | $1.20 - $2.00         |

**Nota:** Los costos de API calls son generalmente mínimos (< $1/mes) a menos que tengas alta frecuencia de lecturas.

---

## 📝 Verificación y Debugging

### Ver Secretos Creados

```bash
# Listar todos los secretos del proyecto
aws secretsmanager list-secrets \
  --filters Key=name,Values=genius/dev/ \
  --region us-east-1

# Ver un secreto específico (sin mostrar valor)
aws secretsmanager describe-secret \
  --secret-id genius/dev/database/credentials \
  --region us-east-1

# Ver el valor de un secreto (requiere permisos)
aws secretsmanager get-secret-value \
  --secret-id genius/dev/database/credentials \
  --region us-east-1 \
  --query SecretString \
  --output text
```

### Ver Logs en las Instancias

```bash
# Conectar a una instancia vía SSM Session Manager
aws ssm start-session --target i-xxxxxxxxxxxxx

# Ver logs de user-data
sudo cat /var/log/user-data.log | grep -i secret

# Verificar que los secretos se descargaron
ls -la /opt/app/secrets/
```

### Outputs de Terraform

Después de aplicar Terraform, puedes obtener los ARNs de los secretos:

```bash
# Ver outputs
terraform output

# Ver ARN de un secreto específico
terraform output db_secret_arn
```

---

## 🚨 Troubleshooting

### Problema: Las instancias no pueden leer secretos

**Solución:**
1. Verificar que el IAM role tenga permisos de Secrets Manager
2. Verificar que los ARNs de secretos estén correctos en la configuración
3. Revisar los logs de user-data: `sudo cat /var/log/user-data.log`

### Problema: Secretos no aparecen en las instancias

**Solución:**
1. Verificar que `create_db_secret` o `create_api_keys_secret` estén en `true`
2. Verificar que los nombres de secretos en `terraform.tfvars` sean correctos
3. Verificar logs de user-data para errores de AWS CLI

### Problema: Error de permisos KMS

**Solución:**
1. Verificar que la clave KMS tenga permisos para el IAM role de EC2
2. Verificar que `secrets_manager_kms_key_ids` tenga el ARN correcto
3. Si no especificas una clave KMS, usar la clave por defecto de Secrets Manager

---

## 📚 Referencias

- [AWS Secrets Manager - Documentación Oficial](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Secrets Manager - Mejores Prácticas](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [Rotación de Secretos en AWS](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)

---

## 📋 Checklist de Implementación

- [ ] Configurar variables en `terraform.tfvars`
- [ ] Revisar permisos IAM (configurados automáticamente)
- [ ] Aplicar cambios con `terraform apply`
- [ ] Verificar que los secretos se crearon en AWS Secrets Manager
- [ ] Verificar que las instancias pueden leer secretos
- [ ] Actualizar aplicación para usar secretos de `/opt/app/secrets/`
- [ ] Configurar rotación automática (opcional, recomendado para producción)
- [ ] Documentar secretos utilizados en tu equipo

---

**Última actualización:** Generado desde la configuración de Terraform  
**Archivos relacionados:**
- `infra/modules/secrets-manager/`
- `infra/envs/{dev,qa,prod}/main.tf`
- `infra/envs/{dev,qa,prod}/terraform.tfvars`
