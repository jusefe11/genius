# Genius Project - Sistema de Contratos

Proyecto de infraestructura como código con Terraform para desplegar un sistema de contratos en AWS, siguiendo buenas prácticas de arquitectura y seguridad.

## 📋 Tabla de Contenidos

- [Estructura del Proyecto](#estructura-del-proyecto)
- [Arquitectura](#arquitectura)
- [Inicio Rápido](#inicio-rápido)
- [Configuración por Ambiente](#configuración-por-ambiente)
- [Módulos Terraform](#módulos-terraform)
- [Configuración Avanzada](#configuración-avanzada)
- [Costos Estimados](#costos-estimados)
- [Troubleshooting](#troubleshooting)

## Estructura del Proyecto

```
genius/
├── infra/
│   ├── modules/              # Módulos reutilizables
│   │   ├── vpc/              # Red (VPC, subredes, NAT Gateway)
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── security_groups/  # Security Groups
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── alb/              # Application Load Balancer
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── autoscaling/      # Auto Scaling Group y EC2
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── user_data.sh
│   │   ├── cloudwatch/       # Monitoreo y alarmas
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── secrets-manager/  # Gestión de secretos
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── backend-setup/        # Backend remoto (S3 + DynamoDB)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── envs/                 # Configuración por ambiente
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   ├── provider.tf
│   │   │   ├── backend.tf
│   │   │   └── outputs.tf
│   │   ├── qa/               # Misma estructura que dev
│   │   └── prod/             # Misma estructura que dev
│   ├── provider.tf
│   ├── backend.tf
│   └── variables.tf
├── app/                      # Aplicación
│   ├── Dockerfile
│   ├── src/
│   └── tests/
├── .github/
│   └── workflows/
│       └── terraform-pipeline.yml
├── .gitignore
└── README.md
```

## Arquitectura

```
Internet
  ↓
Application Load Balancer (ALB) [Subredes Públicas]
  ├─ Security Group: alb-sg (permite 80/443 desde Internet)
  └─ Target Group
      ↓
Auto Scaling Group (ASG) [Subredes Privadas]
  ├─ Security Group: app-sg (solo desde alb-sg)
  ├─ Min: 2 instancias | Deseado: 2 | Max: 5
  ├─ IAM Role: SSM Session Manager (acceso remoto seguro)
  └─ EC2 Instances (acceso a Internet vía NAT Gateway)
```

### Características Principales

- ✅ **Seguridad**: Instancias en subredes privadas, Security Groups restrictivos, Secrets Manager integrado, acceso remoto vía SSM Session Manager
- ✅ **Alta Disponibilidad**: Multi-AZ, Auto Scaling, Health Checks
- ✅ **Monitoreo**: CloudWatch Dashboard y alarmas (CPU, errores, hosts no saludables)
- ✅ **Modularidad**: Módulos reutilizables entre ambientes (dev, qa, prod)
- ✅ **Gestión de Secretos**: AWS Secrets Manager integrado (credenciales de BD, API keys, secretos genéricos)

## Inicio Rápido

### Requisitos Previos

1. **Terraform >= 1.0** instalado
2. **AWS CLI** configurado (`aws configure`)
3. **Permisos IAM** en AWS para crear recursos (VPC, EC2, ALB, etc.)

### Despliegue Básico

```bash
# 1. Navegar al ambiente deseado
cd infra/envs/dev  # o qa, prod

# 2. Inicializar Terraform
terraform init

# 3. Ver el plan de despliegue
terraform plan

# 4. Aplicar la configuración
terraform apply

# 5. Ver outputs (DNS del ALB, etc.)
terraform output

# Ver output específico
terraform output alb_dns_name
```

### Backend Remoto (Opcional pero Recomendado)

Para usar estado remoto compartido (S3 + DynamoDB):

```bash
# 1. Crear backend (solo primera vez)
cd infra/backend-setup
terraform init && terraform apply

# 2. Migrar estado del ambiente
cd ../envs/dev
terraform init -migrate-state
```

## Configuración por Ambiente

| Ambiente | Instancias (min/desired/max) | Instance Type | HTTPS | Deletion Protection |
|----------|------------------------------|---------------|-------|---------------------|
| **dev** | 2/2/5 | t3.micro | ❌ | ❌ |
| **qa** | 2/2/5 | t3.micro | ❌ | ❌ |
| **prod** | 2/2/5 | t3.micro | ❌ | ✅ |

### Configuración de Red

**Dev:**
- VPC: `10.0.0.0/16`
- Subredes públicas: `10.0.1.0/24`, `10.0.2.0/24`
- Subredes privadas: `10.0.10.0/24`, `10.0.20.0/24`

**QA:**
- VPC: `10.1.0.0/16`
- Subredes: `10.1.1.0/24`, `10.1.2.0/24` (públicas) | `10.1.10.0/24`, `10.1.20.0/24` (privadas)

**Prod:**
- VPC: `10.2.0.0/16`
- Subredes: `10.2.1.0/24`, `10.2.2.0/24` (públicas) | `10.2.10.0/24`, `10.2.20.0/24` (privadas)

**Nota**: Todos los ambientes están configurados con la misma capacidad de Auto Scaling (min=2, desired=2, max=5) y tipo de instancia (t3.micro) para facilitar la paridad entre ambientes.

Edita `infra/envs/{ambiente}/terraform.tfvars` para personalizar.

## Módulos Terraform

### 1. VPC (`modules/vpc/`)
Crea VPC con 2 subredes públicas y 2 privadas, Internet Gateway, 2 NAT Gateways (uno por AZ), y tablas de ruteo.

**Outputs principales**: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`

### 2. Security Groups (`modules/security_groups/`)
- **alb-sg**: Permite tráfico HTTP/HTTPS (80/443) desde Internet
- **app-sg**: Permite tráfico solo desde alb-sg (principio de mínimo acceso)
- **db-sg**: Para futuras bases de datos (solo desde app-sg)
- **redis-sg**, **bastion-sg**: Opcionales

### 3. ALB (`modules/alb/`)
Application Load Balancer con Target Group y Listeners (HTTP obligatorio, HTTPS opcional).

**Outputs principales**: `alb_dns_name`, `target_group_arn`, `alb_arn`

### 4. Autoscaling (`modules/autoscaling/`)
Auto Scaling Group con Launch Template. Las instancias:
- Se despliegan en subredes privadas (sin IP público)
- Usan Amazon Linux 2 (selección automática si no se especifica AMI)
- Acceso remoto vía **AWS Systems Manager Session Manager** (no SSH)
- IAM Role con permisos para SSM Session Manager y Secrets Manager
- Ejecutan `user_data.sh` al iniciar (instala Docker, AWS CLI, descarga secretos, despliega app)
- Configuración por defecto: min=2, desired=2, max=5 (igual para todos los ambientes)

**Outputs principales**: `autoscaling_group_name`

### 5. Secrets Manager (`modules/secrets-manager/`)
Gestiona secretos de forma segura:
- **Secreto de BD**: Credenciales de base de datos (username, password, host, port, etc.)
- **Secreto de API Keys**: Múltiples API keys en un solo secreto
- **Secretos genéricos**: Secretos personalizados con contenido arbitrario

Los secretos se descargan automáticamente en `/opt/app/secrets/` al iniciar las instancias en formato JSON y archivos `.env` para variables de entorno.

**Habilitar**: Edita `infra/envs/{ambiente}/terraform.tfvars` y configura `create_db_secret = true`, `create_api_keys_secret = true`, etc. (ver sección de Configuración Avanzada)

### 6. CloudWatch (`modules/cloudwatch/`)
Dashboard y alarmas para:
- Hosts no saludables
- Errores HTTP 5xx
- CPU alto (>80%)

**Outputs principales**: `dashboard_url`, ARNs de alarmas

### 7. Backend Setup (`backend-setup/`)
Crea bucket S3 y tabla DynamoDB para estado remoto de Terraform. **Ejecutar solo una vez**.

## Configuración Avanzada

### Habilitar HTTPS

En `infra/envs/{ambiente}/terraform.tfvars`:

```hcl
enable_https = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
```

### Configurar Secrets Manager

```hcl
# Secreto de BD
create_db_secret = true
db_username      = "myapp_user"
db_password      = "password123"  # ⚠️ Valor sensible
db_host          = "mydb.example.com"
db_port          = 3306
db_name          = "myapp_db"

# API Keys
create_api_keys_secret = true
api_keys = {
  stripe_api_key = "sk_live_xxxxx"
  sendgrid_key   = "SG.xxxxx"
}
```

### Acceso Remoto a Instancias

**Por defecto**: Las instancias usan **AWS Systems Manager Session Manager** (no SSH).

Para conectarte a una instancia:
1. Consola de AWS → EC2 → Instancias
2. Selecciona la instancia → Conectar → Session Manager
3. Se abre una terminal en el navegador

**Nota**: SSH está deshabilitado por defecto. Para habilitarlo (no recomendado):

```hcl
enable_ssh = true
allowed_ssh_cidrs = ["203.0.113.0/24"]  # Tu IP o rango
```

### Cambiar Puerto de Base de Datos

```hcl
db_port   = 5432  # Para PostgreSQL
db_engine = "postgres"
```

## Recursos Creados

Al ejecutar `terraform apply`, se crean aproximadamente:

| Categoría | Cantidad |
|-----------|----------|
| **Recursos de Red** | 10 (VPC, IGW, subredes, NAT, rutas) |
| **Security Groups** | 4-6 (4 obligatorios + 2 opcionales) |
| **Load Balancer** | 3-4 (ALB + Target Group + 1-2 Listeners) |
| **Auto Scaling** | 4 (Launch Template + ASG + 2 políticas) |
| **Instancias EC2** | 2-5 (min=2, desired=2, max=5 por defecto) |
| **CloudWatch** | 4 (3 alarmas + 1 dashboard) |
| **Secrets Manager** | 0-2+N (opcional) |
| **TOTAL** | **~26-52+ recursos** |

## Costos Estimados

**Desarrollo:**
- ~$50-100/mes (2 instancias t3.micro, NAT Gateway, ALB)

**Producción:**
- ~$50-100/mes (configuración actual: 2 instancias t3.micro, NAT Gateway, ALB)
- Costos aumentan con más instancias y tráfico

**Costos principales:**
- NAT Gateway: ~$0.045/hora + datos transferidos
- ALB: ~$0.0225/hora + datos procesados
- EC2: Variable según tipo (t3.micro ~$0.0104/hora)
- Secrets Manager: $0.40/secreto/mes

## Troubleshooting

### Las instancias no reciben tráfico del ALB
- Verificar que `app-sg` permite tráfico desde `alb-sg`
- Verificar health checks del Target Group
- Verificar que las instancias están registradas en el Target Group
- Verificar que las instancias están en estado "healthy" en el Target Group

### Las instancias no pueden acceder a Internet
- Verificar que las subredes privadas tienen tablas de ruteo con NAT Gateway
- Verificar estado del NAT Gateway (debe estar "Available")

### Terraform destroy se demora mucho
- Timeouts configurados para evitar bloqueos
- Dependencias explícitas aseguran orden correcto de destrucción
- Destroy optimizado: ~5-15 minutos (antes: ~20-30 minutos)

### Error al leer secretos en las instancias
- Verificar permisos IAM del rol de EC2 (debe tener acceso a Secrets Manager)
- Verificar que los secretos existen en AWS Secrets Manager
- Verificar que `create_db_secret = true` o `create_api_keys_secret = true` en terraform.tfvars
- Conectarse a la instancia vía Session Manager y revisar logs: `sudo cat /var/log/user-data.log`
- Verificar archivos en `/opt/app/secrets/`: `sudo ls -la /opt/app/secrets/`

### No puedo conectarme a las instancias
- Las instancias usan **SSM Session Manager** (no SSH)
- Conectar desde: Consola AWS → EC2 → Instancias → Conectar → Session Manager
- Verificar que el IAM Role tiene la política `AmazonSSMManagedInstanceCore`
- Verificar que SSM Agent está corriendo: `sudo systemctl status amazon-ssm-agent`

## Características Implementadas

- ✅ **Modularidad**: Módulos reutilizables entre ambientes (dev, qa, prod)
- ✅ **Seguridad**: Subredes privadas, Security Groups restrictivos, Secrets Manager, SSM Session Manager
- ✅ **Alta Disponibilidad**: Multi-AZ, Auto Scaling (2-2-5 por defecto), Health Checks
- ✅ **Monitoreo**: CloudWatch Dashboard y alarmas (CPU, errores, hosts no saludables)
- ✅ **Gestión de Estado**: Backend remoto (S3 + DynamoDB) opcional
- ✅ **Optimizaciones**: Timeouts y dependencias para destroy rápido (~5-15 minutos)
- ✅ **Gestión de Secretos**: AWS Secrets Manager integrado (BD, API keys, secretos genéricos)

## Comandos Útiles

```bash
# Ver estado
terraform show

# Ver outputs
terraform output

# Validar configuración
terraform validate

# Formatear código
terraform fmt

# Destruir infraestructura (¡cuidado!)
terraform destroy
```

## Información Adicional

### Tags FinOps

Todos los recursos incluyen tags para gestión de costos:
- `Project`: genius
- `Environment`: dev/qa/prod
- `CostCenter`: engineering
- `Owner`: platform-team
- `Team`: platform-engineering
- `ManagedBy`: terraform

### Acceso a Instancias

**Método recomendado**: AWS Systems Manager Session Manager
- No requiere claves SSH
- No requiere IPs públicas
- Acceso seguro desde la consola de AWS
- Logs de sesión en CloudTrail

### Configuración Actual

Todos los ambientes están configurados con:
- **Auto Scaling**: min=2, desired=2, max=5
- **Instance Type**: t3.micro (Free Tier elegible)
- **HTTPS**: Deshabilitado (habilitar en producción cuando se tenga certificado)
- **Health Check Path**: `/` (configurable)
- **Secrets Manager**: Deshabilitado por defecto (habilitar según necesidad)

## Referencias

- [Documentación de Terraform](https://www.terraform.io/docs)
- [AWS Provider para Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
