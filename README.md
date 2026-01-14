# 🚀 Genius Project - Sistema de Contratos

> **Infraestructura como Código (IaC)** con Terraform para desplegar una aplicación web escalable y segura en AWS, siguiendo las mejores prácticas de arquitectura cloud y seguridad empresarial.

---

## 📑 Tabla de Contenidos

1. [¿Qué es este proyecto?](#-qué-es-este-proyecto)
2. [Características Principales](#-características-principales)
3. [Arquitectura del Sistema](#-arquitectura-del-sistema)
4. [Estructura del Proyecto](#-estructura-del-proyecto)
5. [Requisitos Previos](#-requisitos-previos)
6. [Guía de Inicio Rápido](#-guía-de-inicio-rápido)
7. [Configuración por Ambiente](#-configuración-por-ambiente)
8. [Módulos Terraform Detallados](#-módulos-terraform-detallados)
9. [Gestión de Secretos](#-gestión-de-secretos)
10. [Monitoreo y Alarmas](#-monitoreo-y-alarmas)
11. [Scripts de Gestión](#-scripts-de-gestión)
12. [Configuración Avanzada](#-configuración-avanzada)
13. [Costos Estimados](#-costos-estimados)
14. [Solución de Problemas](#-solución-de-problemas)
15. [Referencias y Recursos](#-referencias-y-recursos)

---

## 🎯 ¿Qué es este proyecto?

Este proyecto te permite desplegar una **infraestructura completa en AWS** de forma automatizada usando Terraform. La infraestructura incluye:

- 🌐 **Red privada segura** (VPC) con subredes públicas y privadas
- ⚖️ **Balanceador de carga** (ALB) para distribuir tráfico
- 📈 **Auto Scaling** que ajusta automáticamente el número de servidores según la demanda
- 🔐 **Gestión segura de secretos** usando AWS Secrets Manager
- 📊 **Monitoreo y alertas** con CloudWatch
- 🔒 **Acceso remoto seguro** sin necesidad de SSH

**Ideal para**: Aplicaciones web que necesitan alta disponibilidad, seguridad y escalabilidad automática.

---

## ✨ Características Principales

### 🔒 Seguridad de Nivel Empresarial

- ✅ **Instancias en subredes privadas**: Los servidores no tienen IPs públicas, reduciendo la superficie de ataque
- ✅ **Security Groups restrictivos**: Solo permiten el tráfico necesario (principio de mínimo privilegio)
- ✅ **Secrets Manager integrado**: Las contraseñas y API keys nunca se almacenan en código
- ✅ **Acceso remoto vía SSM Session Manager**: Sin necesidad de claves SSH o puertos abiertos
- ✅ **Cifrado en tránsito y reposo**: Todos los secretos están cifrados

### 📈 Alta Disponibilidad y Escalabilidad

- ✅ **Multi-AZ (Multi-Zona de Disponibilidad)**: Los recursos se distribuyen en múltiples zonas para evitar fallos
- ✅ **Auto Scaling automático**: El sistema ajusta el número de servidores según la carga (2-5 servidores por defecto)
- ✅ **Health Checks**: El balanceador verifica constantemente que los servidores estén funcionando
- ✅ **Recuperación automática**: Si un servidor falla, se reemplaza automáticamente

### 📊 Monitoreo Completo

- ✅ **Dashboard de CloudWatch**: Visualización en tiempo real de métricas clave
- ✅ **Alarmas automáticas**: Notificaciones cuando algo va mal (CPU alto, errores, etc.)
- ✅ **Métricas personalizadas**: Monitoreo de CPU, memoria, contenedores Docker, etc.

### 🧩 Modularidad y Reutilización

- ✅ **Módulos reutilizables**: La misma infraestructura se puede usar en dev, qa y producción
- ✅ **Configuración por ambiente**: Cada ambiente tiene su propia configuración
- ✅ **Fácil de mantener**: Cambios en un módulo se propagan a todos los ambientes

---

## 🏗️ Arquitectura del Sistema

### Diagrama de Alto Nivel

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│     Application Load Balancer (ALB)                          │
│     📍 Ubicación: Subredes Públicas                          │
│     🔒 Security Group: Permite HTTP (80) y HTTPS (443)       │
│     ⚖️  Distribuye tráfico entre servidores                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Target Group (Grupo de Destinos)                │
│              Verifica salud de los servidores                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         Auto Scaling Group (ASG)                             │
│         📍 Ubicación: Subredes Privadas                      │
│         🔒 Security Group: Solo desde ALB                    │
│         📊 Configuración: Min=2, Deseado=2, Max=5           │
│                                                              │
│         ┌──────────────┐  ┌──────────────┐                  │
│         │  EC2 Server 1 │  │  EC2 Server 2│                  │
│         │  (Privado)   │  │  (Privado)   │                  │
│         │              │  │              │                  │
│         │  • Docker    │  │  • Docker    │                  │
│         │  • App       │  │  • App       │                  │
│         │  • Secrets   │  │  • Secrets   │                  │
│         └──────────────┘  └──────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              NAT Gateway (Acceso a Internet)                 │
│              Permite a servidores privados                   │
│              descargar actualizaciones                       │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de Tráfico

1. **Usuario accede a la aplicación** → Petición HTTP/HTTPS
2. **ALB recibe la petición** → Verifica reglas de seguridad
3. **ALB distribuye a un servidor** → Selecciona el servidor más saludable
4. **Servidor procesa la petición** → Ejecuta la aplicación
5. **Servidor responde** → Respuesta vuelve al usuario a través del ALB

### Componentes de Seguridad

- **Subredes Privadas**: Los servidores no tienen IPs públicas, solo pueden ser accedidos desde el ALB
- **Security Groups**: Firewalls que controlan qué tráfico puede entrar y salir
- **NAT Gateway**: Permite a los servidores privados acceder a Internet sin exponerlos

---

## 📁 Estructura del Proyecto

```
genius/
│
├── 📂 infra/                          # Infraestructura como Código
│   │
│   ├── 📂 modules/                    # Módulos reutilizables de Terraform
│   │   ├── 📂 vpc/                    # Red virtual (VPC, subredes, NAT)
│   │   │   ├── main.tf                # Recursos principales
│   │   │   ├── variables.tf           # Variables de entrada
│   │   │   └── outputs.tf             # Valores de salida
│   │   │
│   │   ├── 📂 security_groups/        # Reglas de firewall
│   │   ├── 📂 alb/                    # Balanceador de carga
│   │   ├── 📂 autoscaling/            # Auto Scaling Group y servidores EC2
│   │   │   └── user_data.sh           # Script que se ejecuta al iniciar servidores
│   │   ├── 📂 cloudwatch/             # Monitoreo y alarmas
│   │   └── 📂 secrets-manager/        # Gestión de secretos
│   │
│   ├── 📂 backend-setup/              # Configuración del backend remoto (S3 + DynamoDB)
│   │   └── ...                        # Solo se ejecuta una vez
│   │
│   ├── 📂 envs/                       # Configuración por ambiente
│   │   ├── 📂 dev/                    # Ambiente de desarrollo
│   │   │   ├── main.tf                # Define qué módulos usar
│   │   │   ├── variables.tf           # Variables disponibles
│   │   │   ├── terraform.tfvars       # ⚙️ VALORES DE CONFIGURACIÓN (editar aquí)
│   │   │   ├── provider.tf            # Configuración del proveedor AWS
│   │   │   ├── backend.tf             # Dónde guardar el estado de Terraform
│   │   │   └── outputs.tf             # Valores que queremos mostrar
│   │   │
│   │   ├── 📂 qa/                     # Ambiente de QA (misma estructura)
│   │   └── 📂 prod/                   # Ambiente de producción (misma estructura)
│   │
│   ├── 📜 test-metrics.ps1            # Script para probar métricas de CloudWatch
│   ├── 📜 verificar-secretos.ps1      # Script para verificar secretos
│   └── 📜 visualizar-secretos.ps1     # Script para ver contenido de secretos
│
├── 📂 app/                            # Código de la aplicación
│   ├── Dockerfile                     # Imagen Docker de la aplicación
│   └── ...
│
├── 📂 .github/                        # Configuración de CI/CD
│   └── workflows/
│       └── terraform-pipeline.yml    # Pipeline de despliegue automático
│
└── 📄 README.md                       # Este archivo
```

### Explicación de Archivos Clave

- **`terraform.tfvars`**: ⚙️ **Archivo principal de configuración**. Aquí defines los valores específicos de tu ambiente (números de IP, nombres, etc.)
- **`main.tf`**: Define qué módulos usar y cómo conectarlos
- **`variables.tf`**: Define qué variables se pueden configurar
- **`outputs.tf`**: Define qué información mostrar después del despliegue (URLs, IDs, etc.)
- **`user_data.sh`**: Script que se ejecuta automáticamente cuando un servidor inicia (instala software, descarga secretos, etc.)

---

## 🔧 Requisitos Previos

Antes de comenzar, necesitas tener instalado y configurado lo siguiente:

### 1. Terraform (>= 1.0)

**¿Qué es Terraform?** Herramienta que te permite definir infraestructura como código y desplegarla automáticamente.

**Instalación:**

**Windows (PowerShell):**
```powershell
# Descargar desde: https://www.terraform.io/downloads
# O usar Chocolatey:
choco install terraform
```

**Linux/Mac:**
```bash
# Usando el gestor de paquetes de tu distribución
# O descargar binario desde: https://www.terraform.io/downloads
```

**Verificar instalación:**
```bash
terraform version
# Debe mostrar: Terraform v1.x.x
```

### 2. AWS CLI

**¿Qué es AWS CLI?** Herramienta de línea de comandos para interactuar con AWS.

**Instalación:**

**Windows:**
```powershell
# Descargar MSI desde: https://aws.amazon.com/cli/
# O usar: winget install Amazon.AWSCLI
```

**Linux/Mac:**
```bash
# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Mac
brew install awscli
```

**Configuración:**
```bash
aws configure
# Te pedirá:
# - AWS Access Key ID: [tu clave de acceso]
# - AWS Secret Access Key: [tu clave secreta]
# - Default region: us-east-1 (o la región que prefieras)
# - Default output format: json
```

**Verificar configuración:**
```bash
aws sts get-caller-identity
# Debe mostrar tu información de cuenta AWS
```

### 3. Permisos IAM en AWS

Tu usuario de AWS necesita permisos para crear y gestionar:
- VPC (redes virtuales)
- EC2 (servidores)
- ALB (balanceadores de carga)
- IAM (roles y políticas)
- Secrets Manager (gestión de secretos)
- CloudWatch (monitoreo)
- S3 y DynamoDB (si usas backend remoto)

**Permisos recomendados**: `AdministratorAccess` (para desarrollo) o una política personalizada con los permisos específicos.

### 4. PowerShell (para scripts de gestión)

**Windows**: Ya viene instalado
**Linux/Mac**: Instalar PowerShell Core desde: https://github.com/PowerShell/PowerShell

---

## 🚀 Guía de Inicio Rápido

### Paso 1: Clonar o Navegar al Proyecto

```bash
# Si tienes el proyecto en Git
git clone <url-del-repositorio>
cd genius

# O simplemente navega a la carpeta del proyecto
cd c:\Users\tu-usuario\genius
```

### Paso 2: Configurar el Ambiente

Elige el ambiente que quieres desplegar (dev, qa, o prod) y navega a su carpeta:

```bash
cd infra/envs/dev  # Para desarrollo
# o
cd infra/envs/qa    # Para QA
# o
cd infra/envs/prod  # Para producción
```

### Paso 3: Revisar y Personalizar la Configuración

Abre el archivo `terraform.tfvars` en un editor de texto. Este archivo contiene toda la configuración de tu infraestructura.

**Configuración mínima necesaria:**
- `project_name`: Nombre del proyecto (por defecto: "genius")
- `environment`: Ambiente (dev, qa, prod)
- `aws_region`: Región de AWS (por defecto: us-east-1)

**Ejemplo de `terraform.tfvars` básico:**
```hcl
project_name = "genius"
environment  = "dev"
aws_region   = "us-east-1"
```

### Paso 4: Inicializar Terraform

Este comando descarga los módulos y proveedores necesarios:

```bash
terraform init
```

**Salida esperada:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

### Paso 5: Ver el Plan de Despliegue

Antes de crear recursos, Terraform te muestra qué va a hacer:

```bash
terraform plan
```

**¿Qué muestra?**
- ✅ Recursos que se van a crear (en verde con `+`)
- 🔄 Recursos que se van a modificar (en amarillo con `~`)
- ❌ Recursos que se van a eliminar (en rojo con `-`)

**Revisa cuidadosamente** la salida para asegurarte de que es lo que esperas.

### Paso 6: Aplicar la Configuración

Si el plan se ve bien, aplica los cambios:

```bash
terraform apply
```

Terraform te pedirá confirmación. Escribe `yes` y presiona Enter.

**⏱️ Tiempo estimado**: 10-15 minutos para crear toda la infraestructura.

**¿Qué está pasando?**
1. Terraform crea la VPC y las subredes
2. Crea los Security Groups (firewalls)
3. Crea el Application Load Balancer
4. Crea el Auto Scaling Group
5. Lanza las instancias EC2
6. Configura CloudWatch y alarmas
7. (Opcional) Crea secretos en Secrets Manager

### Paso 7: Ver los Resultados

Una vez completado, verás los outputs:

```bash
terraform output
```

**Outputs importantes:**
- `alb_dns_name`: URL del balanceador de carga (ej: `genius-dev-alb-123456.us-east-1.elb.amazonaws.com`)
- `cloudwatch_dashboard_url`: URL del dashboard de monitoreo
- `all_secret_arns`: Lista de secretos creados (si los configuraste)

**🎉 ¡Listo!** Tu infraestructura está desplegada. Puedes acceder a tu aplicación usando la URL del ALB.

---

## 🌍 Configuración por Ambiente

El proyecto soporta múltiples ambientes (desarrollo, QA, producción) con configuraciones independientes.

### Comparación de Ambientes

| Característica | Dev | QA | Prod |
|----------------|-----|-----|------|
| **Instancias** | 2/2/5 | 2/2/5 | 2/2/5 |
| **Tipo de Instancia** | t3.micro | t3.micro | t3.micro |
| **HTTPS** | ❌ No | ❌ No | ✅ Sí (requiere certificado) |
| **Protección de Eliminación** | ❌ No | ❌ No | ✅ Sí |
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Recovery Window (Secretos)** | 7 días | 7 días | 30 días |

### Configuración de Red por Ambiente

Cada ambiente tiene su propia VPC (red virtual) aislada:

**🔵 Desarrollo (Dev):**
```
VPC: 10.0.0.0/16
├── Subredes Públicas:  10.0.1.0/24, 10.0.2.0/24
└── Subredes Privadas:  10.0.10.0/24, 10.0.20.0/24
```

**🟡 QA:**
```
VPC: 10.1.0.0/16
├── Subredes Públicas:  10.1.1.0/24, 10.1.2.0/24
└── Subredes Privadas:  10.1.10.0/24, 10.1.20.0/24
```

**🔴 Producción (Prod):**
```
VPC: 10.2.0.0/16
├── Subredes Públicas:  10.2.1.0/24, 10.2.2.0/24
└── Subredes Privadas:  10.2.10.0/24, 10.2.20.0/24
```

**¿Por qué diferentes rangos de IP?** Para evitar conflictos si necesitas conectar las VPCs en el futuro.

### Personalizar un Ambiente

Edita el archivo `infra/envs/{ambiente}/terraform.tfvars`:

```hcl
# Ejemplo: Cambiar el número de instancias en dev
min_size         = 1  # Mínimo 1 servidor
desired_capacity = 2  # Deseado 2 servidores
max_size         = 3  # Máximo 3 servidores

# Cambiar el tipo de instancia
instance_type = "t3.small"  # Más potente que t3.micro
```

---

## 🧩 Módulos Terraform Detallados

### 1. 🌐 Módulo VPC (`modules/vpc/`)

**¿Qué hace?** Crea la red virtual donde vivirán todos tus recursos.

**Recursos que crea:**
- ✅ **VPC**: Red virtual aislada
- ✅ **Internet Gateway**: Permite acceso a Internet desde subredes públicas
- ✅ **2 Subredes Públicas**: Para recursos que necesitan IP pública (ALB)
- ✅ **2 Subredes Privadas**: Para servidores sin IP pública
- ✅ **2 NAT Gateways**: Permiten a servidores privados acceder a Internet
- ✅ **Tablas de Ruteo**: Definen cómo se enruta el tráfico

**Outputs:**
- `vpc_id`: ID de la VPC creada
- `public_subnet_ids`: IDs de las subredes públicas
- `private_subnet_ids`: IDs de las subredes privadas

**¿Por qué 2 NAT Gateways?** Uno por zona de disponibilidad para alta disponibilidad.

---

### 2. 🔒 Módulo Security Groups (`modules/security_groups/`)

**¿Qué hace?** Crea reglas de firewall que controlan el tráfico de red.

**Security Groups creados:**

| Security Group | Permite Tráfico Desde | Puertos | Uso |
|----------------|----------------------|---------|-----|
| **alb-sg** | Internet (0.0.0.0/0) | 80, 443 | Application Load Balancer |
| **app-sg** | Solo desde alb-sg | 8080 | Servidores de aplicación |
| **db-sg** | Solo desde app-sg | 3306 | Base de datos (futuro) |
| **redis-sg** | Solo desde app-sg | 6379 | Redis/Cache (opcional) |
| **bastion-sg** | IPs específicas | 22 | Servidor bastión (opcional) |

**Principio de Seguridad**: Cada Security Group solo permite el tráfico mínimo necesario (principio de mínimo privilegio).

---

### 3. ⚖️ Módulo ALB (`modules/alb/`)

**¿Qué hace?** Crea un balanceador de carga que distribuye el tráfico entre múltiples servidores.

**Características:**
- ✅ **Distribución de carga**: Divide el tráfico entre servidores disponibles
- ✅ **Health Checks**: Verifica que los servidores estén funcionando
- ✅ **HTTPS opcional**: Soporta certificados SSL/TLS
- ✅ **Multi-AZ**: Distribuido en múltiples zonas de disponibilidad

**Outputs:**
- `alb_dns_name`: URL del balanceador (ej: `genius-dev-alb-123456.us-east-1.elb.amazonaws.com`)
- `target_group_arn`: ARN del grupo de destinos
- `alb_arn`: ARN del balanceador

**¿Cómo funciona?**
1. Usuario accede a la URL del ALB
2. ALB verifica qué servidores están saludables
3. ALB envía la petición a uno de los servidores saludables
4. El servidor responde y el ALB devuelve la respuesta al usuario

---

### 4. 📈 Módulo Autoscaling (`modules/autoscaling/`)

**¿Qué hace?** Crea un grupo de servidores que se ajusta automáticamente según la demanda.

**Componentes:**

**Auto Scaling Group:**
- **Min Size**: Número mínimo de servidores (por defecto: 2)
- **Desired Capacity**: Número deseado de servidores (por defecto: 2)
- **Max Size**: Número máximo de servidores (por defecto: 5)

**Launch Template:**
- Define la configuración de los servidores (tipo, AMI, scripts de inicio, etc.)

**Instancias EC2:**
- Se despliegan en subredes privadas (sin IP pública)
- Ejecutan `user_data.sh` al iniciar
- Tienen acceso a Secrets Manager para descargar secretos
- Acceso remoto vía SSM Session Manager

**¿Qué hace `user_data.sh`?**
1. Actualiza el sistema
2. Instala AWS CLI
3. Instala Docker
4. Instala CloudWatch Agent
5. Descarga secretos de Secrets Manager
6. (Opcional) Despliega la aplicación

**Outputs:**
- `autoscaling_group_name`: Nombre del grupo de auto scaling

---

### 5. 🔐 Módulo Secrets Manager (`modules/secrets-manager/`)

**¿Qué hace?** Gestiona secretos de forma segura (contraseñas, API keys, etc.) sin almacenarlos en código.

**Tipos de secretos soportados:**

#### 5.1. Secreto de Base de Datos

Almacena credenciales de conexión a base de datos:

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

#### 5.2. Secreto de API Keys

Almacena múltiples API keys en un solo secreto:

```json
{
  "stripe_api_key": "sk_live_xxxxx",
  "sendgrid_api_key": "SG.xxxxx",
  "openai_api_key": "sk-xxxxx"
}
```

#### 5.3. Secretos Genéricos

Secretos personalizados con contenido JSON arbitrario:

```json
{
  "secret": "my-jwt-secret-key",
  "algorithm": "HS256"
}
```

**¿Dónde se almacenan los secretos?**
- En las instancias EC2: `/opt/app/secrets/`
- Formato: Archivos JSON y `.env` para variables de entorno

**Seguridad:**
- ✅ Cifrados en reposo (AWS KMS)
- ✅ Cifrados en tránsito (HTTPS)
- ✅ Control de acceso mediante IAM
- ✅ Historial de versiones
- ✅ Rotación automática (opcional)

**Outputs:**
- `db_secret_arn`: ARN del secreto de BD
- `api_keys_secret_arn`: ARN del secreto de API keys
- `all_secret_arns`: Lista de todos los ARNs de secretos

---

### 6. 📊 Módulo CloudWatch (`modules/cloudwatch/`)

**¿Qué hace?** Proporciona monitoreo y alertas para tu infraestructura.

**Componentes:**

#### Dashboard de CloudWatch

Visualización en tiempo real de métricas clave:
- 📈 **CPU Usage**: Uso de CPU de los servidores
- 📊 **Gráficos interactivos**: Puedes hacer zoom, cambiar períodos, etc.

#### Alarmas

Notificaciones automáticas cuando algo va mal:

| Alarma | Se Activa Cuando | Acción Recomendada |
|--------|------------------|-------------------|
| **high-cpu** | CPU > 80% por 1 minuto | Revisar carga o escalar |
| **unhealthy-hosts** | Hosts no saludables | Revisar health checks |
| **http-5xx-errors** | Errores HTTP 5xx | Revisar logs de aplicación |

**Outputs:**
- `dashboard_url`: URL del dashboard de CloudWatch
- `high_cpu_alarm_arn`: ARN de la alarma de CPU alta

**¿Cómo ver el dashboard?**
1. Ejecuta `terraform output cloudwatch_dashboard_url`
2. Abre la URL en tu navegador
3. O usa el script: `.\test-metrics.ps1` y selecciona la opción para abrir el dashboard

---

### 7. 💾 Módulo Backend Setup (`backend-setup/`)

**¿Qué hace?** Crea el almacenamiento remoto para el estado de Terraform.

**¿Por qué es importante?**
- Permite que múltiples personas trabajen en el mismo proyecto
- Evita perder el estado si se borra el archivo local
- Habilita bloqueo de estado (evita conflictos)

**Recursos que crea:**
- ✅ **Bucket S3**: Almacena el archivo de estado
- ✅ **Tabla DynamoDB**: Maneja el bloqueo de estado

**⚠️ IMPORTANTE**: Este módulo solo se ejecuta **una vez** para crear el backend. Después, cada ambiente usa este backend.

**Uso:**
```bash
cd infra/backend-setup
terraform init
terraform apply
```

---

## 🔐 Gestión de Secretos

### ¿Por qué usar Secrets Manager?

**Problema tradicional:**
```bash
# ❌ MAL: Contraseñas en código
DB_PASSWORD="SuperSecret123"  # Expuesto en Git
```

**Solución con Secrets Manager:**
```bash
# ✅ BIEN: Contraseñas en AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id genius/dev/database/credentials
# Solo accesible por recursos autorizados
```

### Configurar Secretos

Edita `infra/envs/{ambiente}/terraform.tfvars`:

#### Ejemplo 1: Secreto de Base de Datos

```hcl
# Habilitar secreto de BD
create_db_secret = true

# Credenciales (⚠️ Valores sensibles)
db_username = "genius_user"
db_password = "GeniusSecurePass2024!"  # Cambia esto por tu contraseña real
db_host     = "genius-db.example.com"   # Cambia esto por tu host real
db_port     = 3306
db_name     = "genius_db"                # Cambia esto por tu nombre de BD
db_engine   = "mysql"                    # mysql, postgres, mongodb, etc.
```

#### Ejemplo 2: Secreto de API Keys

```hcl
# Habilitar secreto de API Keys
create_api_keys_secret = true

# API Keys (⚠️ Valores sensibles)
api_keys = {
  stripe_api_key   = "sk_live_xxxxxxxxxxxxx"      # Tu clave real de Stripe
  sendgrid_api_key = "SG.xxxxxxxxxxxxx"           # Tu clave real de SendGrid
  openai_api_key   = "sk-xxxxxxxxxxxxx"           # Tu clave real de OpenAI
}
```

#### Ejemplo 3: Secretos Genéricos

```hcl
# Secretos personalizados
app_secrets = {
  jwt_secret = {
    description   = "JWT signing secret para autenticacion"
    # ⚠️ IMPORTANTE: Usar cadena JSON directa, NO jsonencode()
    secret_string = "{\"secret\":\"my-jwt-secret-key\",\"algorithm\":\"HS256\"}"
  }
  
  encryption_key = {
    description   = "Clave de encriptacion para datos sensibles"
    secret_string = "{\"key\":\"my-encryption-key-32-chars\"}"
  }
}
```

**⚠️ ERROR COMÚN**: No uses `jsonencode()` en `.tfvars`:
```hcl
# ❌ MAL
secret_string = jsonencode({...})  # Error: Function calls not allowed

# ✅ BIEN
secret_string = "{\"key\":\"value\"}"  # Cadena JSON directa
```

### Aplicar Cambios

Después de configurar los secretos:

```bash
# 1. Ver qué se va a crear
terraform plan

# 2. Aplicar cambios
terraform apply
```

### Verificar Secretos

Usa los scripts incluidos:

```powershell
# Verificar estado de secretos
cd infra
.\verificar-secretos.ps1

# Visualizar contenido de secretos
.\visualizar-secretos.ps1
```

### Acceder a Secretos desde las Instancias

Los secretos se descargan automáticamente en `/opt/app/secrets/` cuando las instancias inician.

**Estructura de archivos:**
```
/opt/app/secrets/
├── genius-dev-database-credentials.json  # Secreto de BD en JSON
├── db.env                                 # Variables de entorno para BD
├── genius-dev-app-api-keys.json          # Secreto de API keys
├── api-keys.env                           # Variables de entorno para API keys
└── ...
```

**Ejemplo de uso en aplicación:**
```bash
# Leer secreto de BD
cat /opt/app/secrets/genius-dev-database-credentials.json

# O usar variables de entorno
source /opt/app/secrets/db.env
echo $DB_USERNAME
echo $DB_PASSWORD
```

---

## 📊 Monitoreo y Alarmas

### Dashboard de CloudWatch

El dashboard muestra métricas en tiempo real de tu infraestructura.

**Acceder al dashboard:**
```bash
# Opción 1: Desde Terraform
cd infra/envs/dev
terraform output cloudwatch_dashboard_url

# Opción 2: Desde el script
cd infra
.\test-metrics.ps1
# Selecciona la opción para abrir el dashboard
```

**Métricas disponibles:**
- 📈 **CPU Usage**: Uso de CPU promedio de todos los servidores
- 📊 **Gráficos interactivos**: Puedes cambiar el período de tiempo, hacer zoom, etc.

### Alarmas Configuradas

| Alarma | Condición | Período | Acción |
|--------|-----------|---------|--------|
| **high-cpu** | CPU > 80% | 1 minuto | Revisar carga o escalar servidores |

**Ver estado de alarmas:**
```bash
# Desde AWS CLI
aws cloudwatch describe-alarms --alarm-names genius-dev-high-cpu

# O desde el script
cd infra
.\test-metrics.ps1
# Selecciona opción 3: Verificar estado de alarmas
```

### Probar Alarmas

El script `test-metrics.ps1` incluye opciones para probar las alarmas:

```powershell
cd infra
.\test-metrics.ps1
```

**Opciones disponibles:**
1. **Saturar CPU**: Genera carga de CPU para activar la alarma
2. **Verificar alarmas**: Muestra el estado actual de todas las alarmas
3. **Diagnóstico de métricas**: Verifica por qué no aparecen métricas

---

## 🛠️ Scripts de Gestión

El proyecto incluye scripts PowerShell para facilitar la gestión de la infraestructura. Todos los scripts deben ejecutarse desde la carpeta `infra/`.

### Scripts de Secrets Manager

#### `gestionar-secretos-eliminados.ps1` ⚠️ IMPORTANTE

**¿Qué hace?** Gestiona secretos que están programados para eliminación (scheduled for deletion).

**¿Cuándo usarlo?** Cuando recibes el error: *"You can't create this secret because a secret with this name is already scheduled for deletion"*

**Uso:**
```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
```

**Opciones del menú:**
1. **Restaurar secretos eliminados** ⭐ RECOMENDADO
   - Restaura los secretos para poder usarlos de nuevo
   - Terraform podrá crear/actualizar los secretos normalmente
   - **No pierdes el contenido** de los secretos

2. **Forzar eliminación inmediata** ⚠️ PELIGROSO
   - Elimina permanentemente los secretos
   - **Perderás todo el contenido** de los secretos
   - Después podrás crear nuevos secretos con los mismos nombres

3. **Esperar período de recuperación**
   - Muestra cuántos días faltan para que se eliminen automáticamente
   - Dev/QA: 7 días | Prod: 30 días

**Ejemplo de salida:**
```
========================================
SECRETOS ELIMINADOS ENCONTRADOS: 4
========================================

  - genius/dev/database/credentials
    Estado: ELIMINADO (programado para borrado)
    Eliminado: 2024-01-10 15:30:00
    Periodo de recuperacion: 7 dias
    Dias restantes: 5

OPCIONES:
  1. Restaurar secretos eliminados (RECOMENDADO)
  2. Forzar eliminacion inmediata
  3. Esperar a que termine el periodo de recuperacion

Selecciona una opcion (1-3): 1

Restaurando: genius/dev/database/credentials...
  [OK] Secreto restaurado exitosamente
```

---

#### `verificar-secretos.ps1`

**¿Qué hace?** Verifica el estado de los secretos configurados.

**Uso:**
```powershell
cd infra
.\verificar-secretos.ps1
```

**Muestra:**
- ✅ Si los secretos están configurados en Terraform
- ✅ Si los secretos existen en AWS Secrets Manager
- ✅ Estado de cada secreto (ACTIVO, ELIMINADO)
- ✅ Información de diagnóstico si hay problemas

**Ejemplo de salida:**
```
========================================
  Verificacion de Secretos AWS
  Secrets Manager
========================================

Region: us-east-1

PASO 1: Obteniendo informacion de Terraform...
OK Prefijo de secretos: genius/dev

OK Se encontraron 4 secretos configurados

PASO 2: Verificando secretos en AWS Secrets Manager...
  [OK] Secreto existe
  Nombre: genius/dev/database/credentials
  Estado: ACTIVO
  Versiones: 1
```

#### `visualizar-secretos.ps1`

**¿Qué hace?** Visualiza el contenido de los secretos (con valores sensibles parcialmente ocultos).

**Uso:**
```powershell
cd infra
.\visualizar-secretos.ps1
```

**Muestra:**
- 📄 Contenido de cada secreto
- 🔒 Valores sensibles parcialmente ocultos (ej: `pass****word`)
- 🔗 URLs directas a la consola de AWS
- 📊 Información detallada de cada secreto

**Ejemplo de salida:**
```
========================================
SECRETO 1 de 4
========================================

ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:genius/dev/database/credentials
Nombre: genius/dev/database/credentials

[CONTENIDO DEL SECRETO (JSON)]:
========================================
  username : genius_user
  password : Geni****2024!
  host : genius-db.example.com
  port : 3306
  database : genius_db
  engine : mysql

[URL EN LA CONSOLA DE AWS]:
  https://console.aws.amazon.com/secretsmanager/...
```

#### `gestionar-secretos-eliminados.ps1`

**¿Qué hace?** Gestiona secretos que están programados para eliminación (scheduled for deletion).

**¿Cuándo usarlo?** Cuando recibes el error: "You can't create this secret because a secret with this name is already scheduled for deletion"

**Uso:**
```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
```

**Opciones:**
1. **Restaurar secretos eliminados** (Recomendado): Restaura los secretos para poder usarlos de nuevo
2. **Forzar eliminación inmediata**: Elimina permanentemente los secretos (perderás el contenido)
3. **Esperar período de recuperación**: Muestra cuántos días faltan para que se eliminen automáticamente

**Ejemplo de salida:**
```
========================================
SECRETOS ELIMINADOS ENCONTRADOS: 4
========================================

OPCIONES:
  1. Restaurar secretos eliminados (RECOMENDADO)
  2. Forzar eliminacion inmediata
  3. Esperar a que termine el periodo de recuperacion

Selecciona una opcion (1-3): 1

Restaurando: genius/dev/database/credentials...
  [OK] Secreto restaurado exitosamente
```

### Scripts de CloudWatch

#### `test-metrics.ps1`

**¿Qué hace?** Permite probar métricas y alarmas de CloudWatch.

**Uso:**
```powershell
cd infra
.\test-metrics.ps1
```

**Opciones del menú:**
1. **Saturar CPU**: Genera carga de CPU para activar la alarma
2. **Verificar alarmas**: Muestra el estado de todas las alarmas
3. **Diagnóstico de métricas**: Verifica por qué no aparecen métricas

**Ejemplo de uso:**
```
========================================
  Prueba de Metricas CloudWatch
  Dashboard: genius-dev-application-status
========================================

ACTIVAR ALARMAS (Pruebas de Fallo):
  1. Widget 1: CPU Usage [high-cpu]
     - Activa cuando CPUUtilization > 80% durante 1 minuto

VERIFICACION:
  3. Verificar estado de todas las alarmas
  7. Verificar metricas de CPU en CloudWatch (diagnostico)

Selecciona una opcion (1-7): 1
```

---

## ⚙️ Configuración Avanzada

### Habilitar HTTPS

Para habilitar HTTPS, necesitas un certificado SSL/TLS en AWS Certificate Manager (ACM).

**Paso 1: Crear certificado en ACM**
1. Ve a AWS Console → Certificate Manager
2. Solicita un certificado público
3. Valida el dominio
4. Copia el ARN del certificado

**Paso 2: Configurar en Terraform**

Edita `infra/envs/{ambiente}/terraform.tfvars`:

```hcl
enable_https = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx-xxxxx-xxxxx"
```

**Paso 3: Aplicar cambios**
```bash
terraform plan
terraform apply
```

**Resultado**: El ALB ahora acepta tráfico HTTPS en el puerto 443 y redirige HTTP a HTTPS automáticamente.

---

### Acceso Remoto a Instancias

**Método recomendado: AWS Systems Manager Session Manager**

**Ventajas:**
- ✅ No requiere claves SSH
- ✅ No requiere IPs públicas
- ✅ Acceso seguro desde la consola de AWS
- ✅ Logs de sesión en CloudTrail
- ✅ No requiere abrir puertos en Security Groups

**Cómo conectarse:**

1. **Desde la Consola de AWS:**
   - Ve a EC2 → Instancias
   - Selecciona la instancia
   - Click en "Conectar"
   - Selecciona "Session Manager"
   - Click en "Conectar"
   - Se abre una terminal en el navegador

2. **Desde AWS CLI:**
   ```bash
   aws ssm start-session --target i-1234567890abcdef0
   ```

**Habilitar SSH (no recomendado):**

Si realmente necesitas SSH, edita `terraform.tfvars`:

```hcl
enable_ssh = true
allowed_ssh_cidrs = ["203.0.113.0/24"]  # Tu IP o rango de IPs
```

**⚠️ Advertencia**: Habilitar SSH expone tus servidores a ataques. Session Manager es más seguro.

---

### Cambiar Configuración de Base de Datos

Para cambiar el puerto o motor de base de datos:

```hcl
# Para PostgreSQL
db_port   = 5432
db_engine = "postgres"

# Para MongoDB
db_port   = 27017
db_engine = "mongodb"

# Para MySQL (por defecto)
db_port   = 3306
db_engine = "mysql"
```

---

### Ajustar Auto Scaling

Para cambiar el número de servidores:

```hcl
min_size         = 1   # Mínimo 1 servidor
desired_capacity = 3   # Deseado 3 servidores
max_size         = 10  # Máximo 10 servidores
```

**Consideraciones:**
- Más servidores = Mayor costo
- Más servidores = Mayor disponibilidad
- El Auto Scaling ajusta automáticamente según la carga (si configuras políticas de escalado)

---

## 💰 Costos Estimados

### Desglose de Costos Mensuales

**Configuración por defecto (2 instancias t3.micro):**

| Recurso | Costo Mensual | Descripción |
|---------|---------------|-------------|
| **NAT Gateway** | ~$32 | $0.045/hora × 2 gateways × 730 horas |
| **Application Load Balancer** | ~$16 | $0.0225/hora × 730 horas |
| **EC2 Instances (t3.micro)** | ~$15 | $0.0104/hora × 2 instancias × 730 horas |
| **Secrets Manager** | ~$1.60 | $0.40/secreto × 4 secretos |
| **CloudWatch** | ~$5 | Métricas y logs (primeros 10GB gratis) |
| **Transferencia de Datos** | Variable | Depende del tráfico |
| **TOTAL ESTIMADO** | **~$70-100/mes** | Sin incluir transferencia de datos |

### Optimización de Costos

**Para desarrollo:**
- Usar 1 instancia en lugar de 2: Ahorro ~$7.50/mes
- Usar 1 NAT Gateway: Ahorro ~$32/mes (menos disponibilidad)
- Deshabilitar secretos no usados: Ahorro ~$0.40/secreto/mes

**Para producción:**
- Considerar instancias reservadas: Hasta 75% de descuento
- Usar Auto Scaling policies: Escalar solo cuando sea necesario
- Monitorear costos con AWS Cost Explorer

### Free Tier

Algunos recursos son elegibles para Free Tier de AWS (primeros 12 meses):
- ✅ EC2 t3.micro: 750 horas/mes gratis
- ✅ Secrets Manager: Primeros secretos pueden tener descuentos
- ⚠️ NAT Gateway: NO está en Free Tier
- ⚠️ ALB: NO está en Free Tier

---

## 🔧 Solución de Problemas

### Problema: Las instancias no reciben tráfico del ALB

**Síntomas:**
- El ALB muestra que los servidores están "unhealthy"
- No puedes acceder a la aplicación desde la URL del ALB

**Soluciones:**

1. **Verificar Security Groups:**
   ```bash
   # Verificar que app-sg permite tráfico desde alb-sg
   aws ec2 describe-security-groups --group-names genius-dev-app-sg
   ```

2. **Verificar Health Checks:**
   - Ve a EC2 → Target Groups
   - Selecciona el target group
   - Revisa la pestaña "Health checks"
   - Verifica que la ruta de health check sea correcta (por defecto: `/`)

3. **Conectarse a una instancia y verificar:**
   ```bash
   # Conectar vía Session Manager
   aws ssm start-session --target i-xxxxx
   
   # Verificar que la aplicación está corriendo
   sudo systemctl status docker
   docker ps
   
   # Verificar logs
   sudo cat /var/log/user-data.log
   ```

---

### Problema: Las instancias no pueden acceder a Internet

**Síntomas:**
- Las instancias no pueden descargar actualizaciones
- No pueden acceder a Secrets Manager
- No pueden hacer llamadas a APIs externas

**Soluciones:**

1. **Verificar NAT Gateway:**
   ```bash
   aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
   ```
   Debe mostrar al menos un NAT Gateway en estado "available"

2. **Verificar Tablas de Ruteo:**
   - Ve a VPC → Route Tables
   - Selecciona la tabla de ruteo de las subredes privadas
   - Verifica que hay una ruta a `0.0.0.0/0` que apunta al NAT Gateway

3. **Verificar desde la instancia:**
   ```bash
   # Conectar vía Session Manager
   aws ssm start-session --target i-xxxxx
   
   # Probar conectividad
   curl https://www.google.com
   ```

---

### Problema: Error "secret is already scheduled for deletion"

**Síntoma:**
```
Error: You can't create this secret because a secret with this name 
is already scheduled for deletion.
```

**Causa:** Los secretos fueron eliminados previamente y están en el período de recuperación (7 días para dev, 30 días para prod). Durante este período, no puedes crear un nuevo secreto con el mismo nombre.

**Solución Rápida (Recomendada):**

**Opción 1: Restaurar los secretos eliminados**

Usa el script incluido:
```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
# Selecciona opción 1: Restaurar secretos eliminados
```

O manualmente con AWS CLI:
```bash
# Restaurar cada secreto
aws secretsmanager restore-secret --secret-id "genius/dev/database/credentials" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/api-keys" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/jwt_secret" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/encryption_key" --region us-east-1

# Luego ejecuta terraform apply de nuevo
cd infra/envs/dev
terraform apply
```

**Opción 2: Forzar eliminación inmediata (si no necesitas los secretos)**

```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
# Selecciona opción 2: Forzar eliminación inmediata
# ⚠️ ADVERTENCIA: Perderás el contenido de los secretos
```

**Opción 3: Esperar el período de recuperación**

Los secretos se eliminarán automáticamente después del período de recuperación (7 días para dev, 30 días para prod). Después podrás crear nuevos secretos con los mismos nombres.

---

### Problema: Error al leer secretos en las instancias

**Síntomas:**
- Los secretos no se descargan en `/opt/app/secrets/`
- La aplicación no puede acceder a las credenciales

**Soluciones:**

1. **Verificar que los secretos existen:**
   ```powershell
   cd infra
   .\verificar-secretos.ps1
   ```

2. **Verificar permisos IAM:**
   ```bash
   # Verificar que el rol de EC2 tiene permisos de Secrets Manager
   aws iam get-role-policy --role-name genius-dev-ssm-role --policy-name genius-dev-secrets-manager-read
   ```

3. **Revisar logs de la instancia:**
   ```bash
   # Conectar vía Session Manager
   aws ssm start-session --target i-xxxxx
   
   # Ver logs de user-data
   sudo cat /var/log/user-data.log | grep -i secret
   
   # Verificar archivos de secretos
   sudo ls -la /opt/app/secrets/
   ```

4. **Verificar configuración en terraform.tfvars:**
   - Asegúrate de que `create_db_secret = true` o `create_api_keys_secret = true`
   - Verifica que los valores no estén vacíos

---

### Problema: Error "secret is already scheduled for deletion"

**Síntoma:**
```
Error: You can't create this secret because a secret with this name 
is already scheduled for deletion.
```

**Causa:** Los secretos fueron eliminados previamente y están en el período de recuperación (7 días para dev, 30 días para prod). Durante este período, AWS no permite crear un nuevo secreto con el mismo nombre.

**Solución Rápida (Recomendada):**

**Opción 1: Restaurar los secretos eliminados** ⭐ RECOMENDADO

Usa el script incluido:
```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
# Selecciona opción 1: Restaurar secretos eliminados
```

O manualmente con AWS CLI:
```bash
# Restaurar cada secreto (reemplaza us-east-1 con tu región)
aws secretsmanager restore-secret --secret-id "genius/dev/database/credentials" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/api-keys" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/jwt_secret" --region us-east-1
aws secretsmanager restore-secret --secret-id "genius/dev/app/encryption_key" --region us-east-1

# Luego ejecuta terraform apply de nuevo
cd infra/envs/dev
terraform apply
```

**Opción 2: Forzar eliminación inmediata** ⚠️ Solo si no necesitas los secretos

```powershell
cd infra
.\gestionar-secretos-eliminados.ps1
# Selecciona opción 2: Forzar eliminación inmediata
# ⚠️ ADVERTENCIA: Perderás el contenido de los secretos
```

**Opción 3: Esperar el período de recuperación**

Los secretos se eliminarán automáticamente después del período de recuperación:
- **Dev/QA**: 7 días
- **Prod**: 30 días

Después de ese tiempo, podrás crear nuevos secretos con los mismos nombres.

**¿Por qué pasa esto?** AWS Secrets Manager tiene un período de recuperación para evitar eliminaciones accidentales. Durante este período, los secretos están "eliminados" pero aún existen y pueden restaurarse.

---

### Problema: Error "Function calls not allowed" en terraform.tfvars

**Síntoma:**
```
Error: Function calls not allowed
  on terraform.tfvars line 90:
  90:     secret_string = jsonencode({...})
```

**Causa:** Las funciones de Terraform como `jsonencode()` no se pueden usar en archivos `.tfvars`.

**Solución:**

❌ **INCORRECTO:**
```hcl
app_secrets = {
  jwt_secret = {
    secret_string = jsonencode({
      secret = "my-jwt-secret"
    })
  }
}
```

✅ **CORRECTO:**
```hcl
app_secrets = {
  jwt_secret = {
    secret_string = "{\"secret\":\"my-jwt-secret\"}"
  }
}
```

**Nota:** Usa cadenas JSON directas, escapando las comillas dobles con `\"`.

---

### Problema: No puedo conectarme a las instancias

**Síntoma:** No puedes acceder a las instancias vía Session Manager.

**Soluciones:**

1. **Verificar que SSM Agent está corriendo:**
   ```bash
   # Desde la consola de AWS, conecta vía Session Manager
   # Si no puedes, verifica desde otra instancia o usa AWS CLI
   ```

2. **Verificar IAM Role:**
   ```bash
   aws iam get-role --role-name genius-dev-ssm-role
   # Debe tener la política AmazonSSMManagedInstanceCore
   ```

3. **Verificar desde la instancia (si tienes otro método de acceso):**
   ```bash
   sudo systemctl status amazon-ssm-agent
   sudo systemctl start amazon-ssm-agent  # Si no está corriendo
   ```

---

### Problema: Terraform destroy se demora mucho

**Síntoma:** `terraform destroy` tarda más de 20 minutos.

**Soluciones:**

1. **Esperar**: Algunos recursos tienen períodos de espera configurados para evitar eliminaciones accidentales
2. **Verificar dependencias**: Asegúrate de que no hay recursos bloqueados
3. **Forzar destrucción (con cuidado):**
   ```bash
   terraform destroy -auto-approve
   ```

**Tiempo estimado:** 5-15 minutos (optimizado)

---

## 📚 Referencias y Recursos

### Documentación Oficial

- 📖 [Terraform Documentation](https://www.terraform.io/docs)
- 📖 [AWS Provider for Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- 📖 [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- 📖 [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- 📖 [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Conceptos Importantes

**Infraestructura como Código (IaC):**
- Define infraestructura usando código en lugar de interfaces gráficas
- Permite versionado, revisión de código y despliegues reproducibles

**Terraform:**
- Herramienta de HashiCorp para IaC
- Usa lenguaje HCL (HashiCorp Configuration Language)
- Soporta múltiples proveedores de cloud (AWS, Azure, GCP, etc.)

**AWS VPC:**
- Red virtual privada aislada en AWS
- Similar a una red física pero virtualizada

**Auto Scaling:**
- Ajusta automáticamente el número de servidores según la demanda
- Aumenta servidores cuando hay mucha carga
- Reduce servidores cuando hay poca carga

---

## 🎓 Información Adicional

### Tags FinOps

Todos los recursos incluyen tags para gestión de costos y organización:

| Tag | Valor | Propósito |
|-----|-------|-----------|
| `Project` | genius | Identifica el proyecto |
| `Environment` | dev/qa/prod | Identifica el ambiente |
| `CostCenter` | engineering | Para asignación de costos |
| `Owner` | platform-team | Equipo responsable |
| `Team` | platform-engineering | Equipo que gestiona |
| `ManagedBy` | terraform | Herramienta de gestión |

### Configuración Actual por Defecto

Todos los ambientes están configurados con:

- **Auto Scaling**: min=2, desired=2, max=5
- **Instance Type**: t3.micro (elegible para Free Tier)
- **HTTPS**: Deshabilitado (habilitar en producción cuando se tenga certificado)
- **Health Check Path**: `/` (configurable)
- **Secrets Manager**: Deshabilitado por defecto (habilitar según necesidad)

### Mejores Prácticas Implementadas

✅ **Seguridad:**
- Instancias en subredes privadas
- Security Groups con principio de mínimo privilegio
- Secretos en Secrets Manager (no en código)
- Acceso remoto vía SSM (no SSH)

✅ **Alta Disponibilidad:**
- Multi-AZ (múltiples zonas de disponibilidad)
- Auto Scaling automático
- Health checks continuos

✅ **Monitoreo:**
- Dashboard de CloudWatch
- Alarmas automáticas
- Métricas personalizadas

✅ **Mantenibilidad:**
- Código modular y reutilizable
- Configuración por ambiente
- Scripts de gestión automatizados

---

## 🤝 Contribuir

Si encuentras errores o tienes sugerencias de mejora:

1. Crea un issue en el repositorio
2. O contacta al equipo de plataforma

---

## 📝 Licencia

[Especificar licencia del proyecto]

---

## 👥 Autores

- **Equipo de Plataforma** - Desarrollo y mantenimiento

---

**Última actualización**: Enero 2024

**Versión**: 1.0.0

---

¡Gracias por usar Genius Project! 🚀
