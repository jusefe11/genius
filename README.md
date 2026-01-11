# Genius Project - Sistema de Contratos

Proyecto de infraestructura como código con Terraform para desplegar un sistema de contratos en AWS, siguiendo buenas prácticas de arquitectura y seguridad. juan ferrer

## Estructura del Proyecto

```
genius/
├── infra/                              # Configuración de infraestructura Terraform
│   ├── modules/                        # Módulos reutilizables y modulares
│   │   ├── vpc/                        # Módulo de red (VPC)
│   │   │   ├── main.tf                # Recursos principales de VPC (con timeouts optimizados)
│   │   │   ├── variables.tf           # Variables de entrada del módulo
│   │   │   └── outputs.tf             # Valores de salida del módulo
│   │   ├── security_groups/           # Módulo de Security Groups
│   │   │   ├── main.tf                # Definición de todos los Security Groups
│   │   │   ├── variables.tf           # Variables del módulo
│   │   │   ├── outputs.tf             # Outputs de IDs de Security Groups
│   │   │   └── COMPONENTES_DESPLIEGUE.md # Documentación detallada de Security Groups
│   │   ├── alb/                       # Módulo de Application Load Balancer
│   │   │   ├── main.tf                # ALB, Target Groups, Listeners (con timeouts y depends_on)
│   │   │   ├── variables.tf           # Variables de configuración del ALB
│   │   │   └── outputs.tf             # Outputs del ALB (DNS, ARNs, etc.)
│   │   ├── autoscaling/               # Módulo de Auto Scaling Group
│   │   │   ├── main.tf                # Launch Template y ASG
│   │   │   ├── variables.tf           # Variables de ASG
│   │   │   ├── outputs.tf             # Outputs del ASG
│   │   │   └── user_data.sh           # Script de inicialización de instancias
│   │   ├── cloudwatch/                # Módulo de CloudWatch (Monitoreo)
│   │   │   ├── main.tf                # Alarmas y Dashboard de CloudWatch
│   │   │   ├── variables.tf           # Variables de configuración de CloudWatch
│   │   │   └── outputs.tf             # Outputs de Alarmas y Dashboard
│   │   └── secrets-manager/           # Módulo de AWS Secrets Manager
│   │       ├── main.tf                # Secretos de base de datos, API keys y genéricos
│   │       ├── variables.tf           # Variables de configuración de secretos
│   │       └── outputs.tf             # Outputs de ARNs y nombres de secretos
│   ├── backend-setup/                 # Setup del Backend Remoto de Terraform
│   │   ├── main.tf                    # Bucket S3 y tabla DynamoDB para estado remoto
│   │   ├── variables.tf               # Variables del backend setup
│   │   ├── outputs.tf                 # Outputs del backend (bucket name, etc.)
│   │   └── README.md                  # Guía para configurar el backend remoto
│   ├── envs/                          # Configuración por ambiente
│   │   ├── dev/                       # Ambiente de desarrollo
│   │   │   ├── main.tf                # Orquestación de módulos para dev
│   │   │   ├── variables.tf           # Variables del ambiente dev
│   │   │   ├── terraform.tfvars       # Valores específicos de dev
│   │   │   ├── provider.tf            # Configuración del provider AWS
│   │   │   ├── backend.tf             # Configuración del backend remoto (S3 + DynamoDB)
│   │   │   └── outputs.tf             # Outputs del ambiente dev
│   │   ├── qa/                        # Ambiente de QA (igual estructura que dev)
│   │   └── prod/                      # Ambiente de producción (igual estructura)
│   ├── provider.tf                    # Provider AWS (configuración base)
│   └── backend.tf                     # Backend de Terraform (opcional, S3)
├── app/                               # Aplicación y código fuente
│   └── Dockerfile                     # Dockerfile de la aplicación
├── .github/                           # Workflows de CI/CD
│   └── workflows/
│       └── terraform-pipeline.yml     # Pipeline de CI/CD para Terraform
├── README.md                          # Este archivo - Documentación principal
├── TABLA_DESPLIEGUE_DEV.md            # Tabla detallada de recursos para ambiente DEV
└── infra/
    ├── GUIA_SECRETS_MANAGER.md        # Guía completa de uso de AWS Secrets Manager
    ├── EXPLICACION_RECURSOS_POR_AMBIENTE.md  # Explicación de variación de recursos
    └── ...
```

## Arquitectura de la Infraestructura

La infraestructura está diseñada siguiendo el principio de **defensa en profundidad** y **mínimo acceso necesario**. La arquitectura completa sigue este flujo:

```
Internet
  ↓
Application Load Balancer (ALB) [Subredes Públicas - AZ 1 y 2]
  ├─ Security Group: alb-sg (permite 80/443 desde Internet)
  └─ Target Group (health checks en puerto 8080)
      ↓
Auto Scaling Group (ASG) [Subredes Privadas - AZ 1 y 2]
  ├─ Launch Template (define configuración de instancias)
  ├─ Security Group: app-sg (permite tráfico solo desde alb-sg)
  ├─ Mínimo: 1-2 instancias
  ├─ Deseado: 2-3 instancias
  └─ Máximo: 5-20 instancias (según ambiente)
      ↓
EC2 Instances [Subredes Privadas]
  └─ Acceso a Internet vía NAT Gateway (no IP público)
```

### Características de Seguridad

- ✅ **Instancias en subredes privadas**: Sin exposición directa a Internet
- ✅ **Principio de mínimo acceso**: Security Groups con reglas específicas
- ✅ **Salida controlada**: NAT Gateway para acceso a Internet desde instancias privadas
- ✅ **Multi-AZ**: Alta disponibilidad en al menos 2 zonas de disponibilidad
- ✅ **Auto Scaling**: Escalado automático basado en carga
- ✅ **Health Checks**: Monitoreo continuo del estado de las instancias
- ✅ **AWS Secrets Manager**: Gestión centralizada y segura de credenciales y secretos

### Características de Monitoreo

- ✅ **CloudWatch Dashboard**: Dashboard con métricas clave (Healthy Hosts, Request Count, Response Time, CPU)
- ✅ **CloudWatch Alarms**: Alarmas configuradas para instancias no saludables, errores 5xx y CPU alto
- ✅ **Métricas automáticas**: Métricas de ALB y EC2 sin configuración adicional

## Tabla de Componentes Desplegados

La siguiente tabla detalla todos los recursos de AWS que se crean al ejecutar `terraform apply` en cualquier ambiente:

### 🔷 RED Y CONECTIVIDAD

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 1 | VPC | `aws_vpc.main` | VPC | 1 | VPC dedicada con DNS habilitado |
| 2 | VPC | `aws_internet_gateway.main` | Internet Gateway | 1 | Gateway para acceso público a Internet |
| 3 | VPC | `aws_subnet.public` | Subnet | 2 | Subredes públicas (una por AZ) |
| 4 | VPC | `aws_subnet.private` | Subnet | 2 | Subredes privadas (una por AZ) |
| 5 | VPC | `aws_eip.nat` | Elastic IP | 2 | IPs elásticas para NAT Gateways |
| 6 | VPC | `aws_nat_gateway.main` | NAT Gateway | 2 | NAT Gateways para salida a Internet |
| 7 | VPC | `aws_route_table.public` | Route Table | 1 | Tabla de ruteo para subredes públicas |
| 8 | VPC | `aws_route_table.private` | Route Table | 2 | Tablas de ruteo para subredes privadas |
| 9 | VPC | `aws_route_table_association.public` | Route Table Association | 2 | Asociación subredes públicas |
| 10 | VPC | `aws_route_table_association.private` | Route Table Association | 2 | Asociación subredes privadas |

### 🔒 SEGURIDAD

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 11 | Security Groups | `aws_security_group.alb` | Security Group | 1 | SG para ALB (permite 80/443 desde Internet) |
| 12 | Security Groups | `aws_security_group.web` | Security Group | 1 | SG para servidores web (alias de alb-sg) |
| 13 | Security Groups | `aws_security_group.app` | Security Group | 1 | SG para app (solo desde alb-sg) |
| 14 | Security Groups | `aws_security_group.db` | Security Group | 1 | SG para bases de datos (solo desde app-sg) |
| 15 | Security Groups | `aws_security_group.redis` | Security Group | 0-1 | SG para Redis (opcional, si enable_redis=true) |
| 16 | Security Groups | `aws_security_group.bastion` | Security Group | 0-1 | SG para Bastion (opcional, si enable_ssh=true) |

### ⚖️ LOAD BALANCER

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 17 | ALB | `aws_lb.main` | Application Load Balancer | 1 | Load Balancer público en subredes públicas |
| 18 | ALB | `aws_lb_target_group.app` | Target Group | 1 | Grupo de destino para instancias EC2 |
| 19 | ALB | `aws_lb_listener.http` | Listener | 1 | Listener HTTP (puerto 80) |
| 20 | ALB | `aws_lb_listener.https` | Listener | 0-1 | Listener HTTPS (opcional, si enable_https=true) |

### 💻 COMPUTO Y AUTO SCALING

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 21 | Autoscaling | `aws_launch_template.app` | Launch Template | 1 | Template para lanzar instancias EC2 |
| 22 | Autoscaling | `aws_autoscaling_group.app` | Auto Scaling Group | 1 | Grupo de Auto Scaling |
| 23 | Autoscaling | `aws_autoscaling_policy.scale_up` | Auto Scaling Policy | 1 | Política de escalado hacia arriba |
| 24 | Autoscaling | `aws_autoscaling_policy.scale_down` | Auto Scaling Policy | 1 | Política de escalado hacia abajo |
| 25 | Autoscaling | `aws_instance` (vía ASG) | EC2 Instance | 1-20 | Instancias EC2 (variable según ASG) |

### 📊 MONITOREO Y ALARMAS

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 26 | CloudWatch | `aws_cloudwatch_metric_alarm.unhealthy_hosts` | CloudWatch Alarm | 1 | Alarma de instancias no saludables |
| 27 | CloudWatch | `aws_cloudwatch_metric_alarm.http_5xx_errors` | CloudWatch Alarm | 1 | Alarma de errores HTTP 5xx |
| 28 | CloudWatch | `aws_cloudwatch_metric_alarm.high_cpu` | CloudWatch Alarm | 1 | Alarma de CPU alto |
| 29 | CloudWatch | `aws_cloudwatch_dashboard.main` | CloudWatch Dashboard | 1 | Dashboard de monitoreo de aplicación |

### 🔐 SECRETOS Y GESTIÓN DE CREDENCIALES

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 30 | Secrets Manager | `aws_secretsmanager_secret.db_credentials` | Secret | 0-1 | Secreto de credenciales de base de datos (opcional) |
| 31 | Secrets Manager | `aws_secretsmanager_secret_version.db_credentials` | Secret Version | 0-1 | Versión del secreto de BD |
| 32 | Secrets Manager | `aws_secretsmanager_secret.api_keys` | Secret | 0-1 | Secreto de API Keys (opcional) |
| 33 | Secrets Manager | `aws_secretsmanager_secret_version.api_keys` | Secret Version | 0-1 | Versión del secreto de API Keys |
| 34 | Secrets Manager | `aws_secretsmanager_secret.app_secrets` | Secret | 0-N | Secretos genéricos personalizados |
| 35 | Secrets Manager | `aws_secretsmanager_secret_version.app_secrets` | Secret Version | 0-N | Versiones de secretos genéricos |

### 📊 DATA SOURCES

| # | Módulo | Recurso AWS | Tipo | Cantidad | Descripción |
|---|--------|-------------|------|----------|-------------|
| 36 | Env | `data.aws_ami.amazon_linux` | Data Source | 0-1 | Obtiene AMI más reciente (si ami_id vacío) |

### Resumen por Categoría

| Categoría | Cantidad Mínima | Cantidad Máxima | Notas |
|-----------|----------------|-----------------|-------|
| **Recursos de Red** | 10 | 10 | Fijos (VPC, IGW, subredes, NAT, rutas) |
| **Security Groups** | 4 | 6 | 4 obligatorios + 2 opcionales (redis, bastion) |
| **Load Balancer** | 3 | 4 | ALB + Target Group + 1-2 Listeners |
| **Auto Scaling** | 4 | 4 | Launch Template + ASG + 2 políticas |
| **Instancias EC2** | 1 | 20 | Variable según configuración del ASG |
| **CloudWatch** | 4 | 4 | 3 Alarmas + 1 Dashboard |
| **Secrets Manager** | 0 | 2+N | Secretos opcionales (BD, API keys, genéricos) |
| **Data Sources** | 0 | 1 | Solo si no se especifica AMI ID |
| **TOTAL** | **26** | **52+** | Depende de configuración y opciones habilitadas |

### Cantidad de Recursos por Ambiente

| Ambiente | Instancias EC2 | Listeners ALB | Security Groups | CloudWatch | Total Aprox. |
|----------|----------------|---------------|-----------------|------------|--------------|
| **dev** | 1-5 | 1-2 | 4-6 | 4 | ~29-34 recursos |
| **qa** | 2-10 | 1-2 | 4-6 | 4 | ~34-39 recursos |
| **prod** | 2-20 | 2 | 4-6 | 4 | ~39-49 recursos |

### Notas Importantes sobre la Tabla

1. **Recursos Fijos**: Los recursos de red (VPC, subredes, NAT, etc.) son siempre los mismos independientemente del ambiente
2. **Recursos Variables**: Las instancias EC2 varían según la configuración del ASG (min/desired/max)
3. **Recursos Opcionales**: 
   - `redis-sg` y `bastion-sg` solo se crean si se habilitan en `terraform.tfvars`
   - Listener HTTPS solo se crea si `enable_https = true` y se proporciona `certificate_arn`
4. **Data Source**: El data source `aws_ami` solo se ejecuta si `ami_id` está vacío en `terraform.tfvars`
5. **Tagging**: Todos los recursos incluyen tags: `Project`, `Environment`, y `Name`

## Estructura Detallada de los Módulos Terraform

### 1. Módulo VPC (`infra/modules/vpc/`)

**Propósito**: Crea una VPC dedicada con red completa y ruteo configurado.

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_vpc.main` | VPC dedicada (no usa la por defecto) | DNS habilitado, CIDR configurable |
| `aws_internet_gateway.main` | Gateway para acceso a Internet | Asociado a la VPC |
| `aws_subnet.public[0..N]` | Subredes públicas (2 por defecto) | Una por AZ, `map_public_ip_on_launch = true` |
| `aws_subnet.private[0..N]` | Subredes privadas (2 por defecto) | Una por AZ, sin IP pública |
| `aws_eip.nat[0..N]` | Elastic IPs para NAT Gateways | Una por cada NAT Gateway |
| `aws_nat_gateway.main[0..N]` | NAT Gateways | Uno en cada subred pública (alta disponibilidad) |
| `aws_route_table.public` | Tabla de ruteo pública | Ruta `0.0.0.0/0` → Internet Gateway |
| `aws_route_table.private[0..N]` | Tablas de ruteo privadas | Ruta `0.0.0.0/0` → NAT Gateway correspondiente |

**Optimizaciones de Destroy**:
- ✅ **Timeouts configurados** para todos los recursos críticos:
  - VPC: `create: 10m`, `delete: 15m`
  - Internet Gateway: `create: 5m`, `delete: 10m`
  - NAT Gateway: `create: 10m`, `delete: 10m` (reduce destroy de ~20min a ~5-10min)
  - Elastic IP: `read: 5m`, `delete: 10m`
- ✅ **Dependencias explícitas** (`depends_on`) para orden correcto de destrucción:
  - Elastic IP depende del Internet Gateway
  - NAT Gateway depende del Internet Gateway
  - Route Tables dependen de IGW/NAT según corresponda
  - Evita error: `Network has some mapped public address(es)`

**Variables principales**:
- `vpc_cidr`: CIDR de la VPC (ej: `10.0.0.0/16`)
- `public_subnet_cidrs`: Lista de CIDRs para subredes públicas
- `private_subnet_cidrs`: Lista de CIDRs para subredes privadas
- `availability_zones`: Zonas de disponibilidad a usar

**Outputs**:
- `vpc_id`, `vpc_cidr`
- `public_subnet_ids`, `private_subnet_ids`
- `internet_gateway_id`, `nat_gateway_ids`
- `public_route_table_id`, `private_route_table_ids`

### 2. Módulo Security Groups (`infra/modules/security_groups/`)

**Propósito**: Define Security Groups con principio de mínimo acceso necesario.

**Security Groups creados**:

#### **alb-sg** (Application Load Balancer Security Group)
```hcl
Ingress:
  - Puerto 80 (HTTP) desde Internet (0.0.0.0/0)
  - Puerto 443 (HTTPS) desde Internet (0.0.0.0/0)
  - Puerto 22 (SSH) opcional desde IPs específicas (si enable_ssh = true)

Egress:
  - Todo el tráfico saliente (0.0.0.0/0)
```

#### **app-sg** (Application Security Group) - **CRÍTICO**
```hcl
Ingress:
  - Puerto de aplicación (default 8080) SOLO desde alb-sg ⚠️
  - Puerto 22 (SSH) opcional desde IPs específicas
  - Comunicación self (entre instancias de la app)

Egress:
  - Todo el tráfico saliente (para actualizaciones, llamadas API, etc.)
```
**Nota importante**: El `app-sg` solo acepta tráfico desde `alb-sg`, implementando el principio de mínimo acceso.

#### **db-sg** (Database Security Group) - *Opcional, para futuras bases de datos*
```hcl
Ingress:
  - Puerto de BD (default 3306) SOLO desde app-sg
  - Comunicación self (para replicación)

Egress:
  - Tráfico limitado solo para replicación y backups
```

#### **web-sg** (Web Security Group)
Alias del `alb-sg` para compatibilidad con código existente. Tiene las mismas reglas que `alb-sg`.

#### **redis-sg** (Redis Security Group) - *Opcional*
```hcl
Ingress:
  - Puerto 6379 (Redis) SOLO desde app-sg
  - Puerto 16379 (Redis Cluster) SOLO desde app-sg
  - Comunicación self
```

#### **bastion-sg** (Bastion Security Group) - *Opcional*
```hcl
Ingress:
  - Puerto 22 (SSH) SOLO desde IPs permitidas

Egress:
  - Todo el tráfico saliente
```

**Variables principales**:
- `vpc_id`: ID de la VPC donde crear los Security Groups
- `app_port`: Puerto de la aplicación (default: 8080)
- `db_port`: Puerto de la base de datos (default: 3306)
- `enable_ssh`: Habilitar acceso SSH (default: false)
- `allowed_ssh_cidrs`: Lista de CIDRs permitidas para SSH
- `allowed_web_cidrs`: CIDRs permitidas para acceso web (default: `["0.0.0.0/0"]`)

**Outputs**:
- `alb_security_group_id`, `app_security_group_id`, `db_security_group_id`
- `web_security_group_id` (alias)

### 3. Módulo ALB (`infra/modules/alb/`)

**Propósito**: Crea un Application Load Balancer con Target Groups y Listeners configurados.

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_lb.main` | Application Load Balancer | Tipo: application, interno: false (público) |
| `aws_lb_target_group.app` | Target Group para la aplicación | Puerto configurable, health checks |
| `aws_lb_listener.http` | Listener HTTP (puerto 80) | Redirige a HTTPS si está habilitado, sino forward a target group |
| `aws_lb_listener.https` | Listener HTTPS (puerto 443) | Opcional, requiere certificate_arn |

**Configuración de Health Checks**:
- **Path**: Configurable (default: `/`)
- **Intervalo**: 30 segundos
- **Timeout**: 5 segundos
- **Healthy threshold**: 2
- **Unhealthy threshold**: 2
- **Protocol**: HTTP
- **Matcher**: Códigos HTTP exitosos (default: `200`)

**Variables principales**:
- `vpc_id`: ID de la VPC
- `public_subnet_ids`: IDs de subredes públicas donde desplegar el ALB
- `security_group_ids`: Lista de Security Groups para el ALB (debe incluir `alb-sg`)
- `app_port`: Puerto de la aplicación en los targets
- `health_check_path`: Ruta para health checks
- `enable_https`: Habilitar HTTPS (default: false)
- `certificate_arn`: ARN del certificado SSL/TLS (requerido si `enable_https = true`)
- `enable_deletion_protection`: Protección contra eliminación (default: false, true en prod)

**Optimizaciones de Destroy**:
- ✅ **Deletion Protection**: Siempre configurado como `false` para permitir destroy rápido
- ✅ **Timeouts configurados**: 
  - `create: 10m`
  - `update: 10m`
  - `delete: 15m`
- ✅ **Dependencias explícitas**: `depends_on` configurado para orden correcto de destrucción (Target Group → Listeners → ALB)

**Outputs**:
- `alb_dns_name`: DNS del ALB (para acceder a la aplicación)
- `alb_zone_id`: Zone ID del ALB (útil para Route53)
- `target_group_arn`: ARN del Target Group (para asociar con ASG)
- `alb_arn`: ARN completo del ALB (para CloudWatch y otros servicios)

### 5. Módulo Secrets Manager (`infra/modules/secrets-manager/`)

**Propósito**: Gestiona secretos de forma segura usando AWS Secrets Manager (credenciales de base de datos, API keys, y secretos genéricos).

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_secretsmanager_secret.db_credentials` | Secreto de credenciales de BD | Opcional, solo si `create_db_secret = true` |
| `aws_secretsmanager_secret_version.db_credentials` | Versión del secreto de BD | Contiene: username, password, host, port, database, engine |
| `aws_secretsmanager_secret.api_keys` | Secreto de API Keys | Opcional, solo si `create_api_keys_secret = true` |
| `aws_secretsmanager_secret_version.api_keys` | Versión del secreto de API Keys | Contiene mapa clave-valor de API keys |
| `aws_secretsmanager_secret.app_secrets` | Secretos genéricos | Personalizables, múltiples secretos permitidos |
| `aws_secretsmanager_secret_version.app_secrets` | Versiones de secretos genéricos | Contenido personalizado (JSON, texto, etc.) |

**Tipos de Secretos Soportados**:

1. **Secreto de Base de Datos** (`database/credentials`):
   - Almacena credenciales completas: username, password, host, port, database, engine
   - Formato JSON estructurado
   - Automáticamente descargado en las instancias en `/opt/app/secrets/db.env`

2. **Secreto de API Keys** (`app/api-keys`):
   - Almacena múltiples API keys en un solo secreto
   - Formato JSON con clave-valor
   - Automáticamente descargado en `/opt/app/secrets/api-keys.env`

3. **Secretos Genéricos** (`app/*`):
   - Permite crear secretos personalizados con contenido arbitrario
   - Útil para JWT secrets, claves de encriptación, configuraciones sensibles, etc.

**Integración con Instancias EC2**:

- **Permisos IAM**: Las instancias tienen permisos para leer secretos específicos del proyecto/ambiente
- **Descarga automática**: El `user_data.sh` descarga secretos al iniciar cada instancia
- **Ubicación**: Secretos almacenados en `/opt/app/secrets/` con permisos restrictivos (600)
- **Formatos disponibles**: JSON y archivos `.env` para variables de entorno

**Variables principales**:
- `create_db_secret`: Habilitar creación de secreto de BD (default: false)
- `db_username`, `db_password`, `db_host`, `db_port`, `db_name`, `db_engine`: Credenciales de BD
- `create_api_keys_secret`: Habilitar creación de secreto de API Keys (default: false)
- `api_keys`: Mapa de API keys (clave-valor)
- `app_secrets`: Mapa de secretos genéricos con descripción y contenido
- `secrets_manager_kms_key_ids`: ARNs de claves KMS para cifrado (opcional)

**Outputs**:
- `db_secret_arn`, `db_secret_name`: ARN y nombre del secreto de BD
- `api_keys_secret_arn`, `api_keys_secret_name`: ARN y nombre del secreto de API Keys
- `app_secrets_arns`, `app_secrets_names`: Mapas de ARNs y nombres de secretos genéricos
- `all_secret_arns`: Lista de todos los ARNs de secretos creados
- `secrets_prefix`: Prefijo común para todos los secretos (`{project}/{environment}`)

**Documentación adicional**: Ver `infra/GUIA_SECRETS_MANAGER.md` para guía completa de uso.

### 6. Módulo Autoscaling (`infra/modules/autoscaling/`)

### 4. Módulo Autoscaling (`infra/modules/autoscaling/`)

**Propósito**: Crea un Auto Scaling Group con Launch Template para gestionar instancias EC2.

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_launch_template.app` | Template de lanzamiento de instancias | Define AMI, tipo, SG, user_data |
| `aws_autoscaling_group.app` | Auto Scaling Group | Asociado a subredes privadas y target group |
| `aws_autoscaling_policy.scale_up` | Política de escalado hacia arriba | Ajuste: +1 instancia, cooldown: 300s |
| `aws_autoscaling_policy.scale_down` | Política de escalado hacia abajo | Ajuste: -1 instancia, cooldown: 300s |

**Launch Template**:
- **NO usa `aws_instance`** directo (según requerimientos)
- Define configuración de instancias EC2
- Usa `user_data.sh` para inicialización automática
- Tagging automático de instancias

**Auto Scaling Group**:
- **Ubicación**: Subredes privadas (no públicas)
- **Health Check Type**: ELB (usando health checks del ALB)
- **Capacidades**: Min, Desired, Max configurables
- **Integración**: Conectado al Target Group del ALB

**User Data Script** (`user_data.sh`):
- Actualiza el sistema
- Instala Docker
- Inicia un contenedor de prueba (placeholder)
- **Nota**: En producción, reemplazar con la aplicación real

**Variables principales**:
- `ami_id`: AMI ID para las instancias (puede ser vacío para usar data source)
- `instance_type`: Tipo de instancia (ej: `t3.micro`, `t3.small`, `t3.medium`)
- `key_name`: Nombre de clave SSH (opcional, puede ser null)
- `security_group_ids`: Lista de Security Groups (debe incluir `app-sg`)
- `subnet_ids`: IDs de subredes privadas
- `target_group_arns`: ARNs de Target Groups del ALB
- `min_size`, `max_size`, `desired_capacity`: Capacidades del ASG
- `app_port`: Puerto de la aplicación

**Outputs**:
- `launch_template_id`, `launch_template_arn`
- `autoscaling_group_id`, `autoscaling_group_name`
- `scale_up_policy_arn`, `scale_down_policy_arn`

### 5. Módulo CloudWatch (`infra/modules/cloudwatch/`)

**Propósito**: Crea alarmas y dashboard de monitoreo para la aplicación usando AWS CloudWatch.

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_cloudwatch_metric_alarm.unhealthy_hosts` | Alarma de instancias no saludables | Se activa cuando hay hosts no saludables en el Target Group |
| `aws_cloudwatch_metric_alarm.http_5xx_errors` | Alarma de errores 5xx | Se activa cuando hay errores HTTP 5xx (default: >5 errores en 5 min) |
| `aws_cloudwatch_metric_alarm.high_cpu` | Alarma de CPU alto | Se activa cuando CPU > umbral (default: >80% durante 2 períodos) |
| `aws_cloudwatch_dashboard.main` | Dashboard de monitoreo | Dashboard con métricas clave de la aplicación |

**Alarmas configuradas**:

1. **Unhealthy Hosts**:
   - Métrica: `UnHealthyHostCount` del Target Group
   - Namespace: `AWS/ApplicationELB`
   - Umbral: > 0 hosts no saludables
   - Evaluación: 1 período de 60 segundos

2. **HTTP 5xx Errors**:
   - Métrica: `HTTPCode_Target_5XX_Count` del ALB
   - Namespace: `AWS/ApplicationELB`
   - Umbral: Configurable (default: >5 errores)
   - Evaluación: 1 período de 300 segundos

3. **High CPU**:
   - Métrica: `CPUUtilization` del ASG
   - Namespace: `AWS/EC2`
   - Umbral: Configurable (default: >80%)
   - Evaluación: 2 períodos de 300 segundos

**Dashboard de CloudWatch**:

El dashboard incluye 4 widgets principales:

1. **Healthy Hosts** (Single Value): Muestra el número actual de hosts saludables
2. **Request Count** (Time Series): Gráfico de línea con el número de solicitudes en el tiempo
3. **Response Time** (Time Series): Tiempo de respuesta promedio en segundos
4. **CPU Usage** (Time Series): Uso de CPU promedio del ASG en porcentaje

**Variables principales**:
- `alb_arn`: ARN del Application Load Balancer
- `target_group_arn`: ARN del Target Group
- `target_group_name`: Nombre del Target Group
- `asg_name`: Nombre del Auto Scaling Group
- `cpu_threshold`: Umbral de CPU para alarma (default: 80)
- `error_5xx_threshold`: Umbral de errores 5xx (default: 5)

**Outputs**:
- `unhealthy_hosts_alarm_arn`: ARN de la alarma de hosts no saludables
- `http_5xx_errors_alarm_arn`: ARN de la alarma de errores 5xx
- `high_cpu_alarm_arn`: ARN de la alarma de CPU alto
- `dashboard_url`: URL del dashboard de CloudWatch

**Nota**: Las alarmas están configuradas para no activarse cuando no hay datos (`treat_missing_data = "notBreaching"`), lo cual es útil durante despliegues o cuando no hay tráfico.

### 6. Backend Setup (`infra/backend-setup/`)

**Propósito**: Crea los recursos necesarios para el backend remoto de Terraform (S3 + DynamoDB para estado remoto y bloqueo).

**⚠️ IMPORTANTE**: Este setup se ejecuta **UNA SOLA VEZ** antes de usar los backends remotos en los ambientes. Se ejecuta con backend local porque estamos creando los recursos que almacenarán el estado.

**Recursos creados**:

| Recurso | Descripción | Configuración |
|---------|-------------|---------------|
| `aws_s3_bucket.terraform_state` | Bucket S3 para estado de Terraform | Versionado habilitado, encriptación AES256, acceso público bloqueado |
| `aws_s3_bucket_versioning.terraform_state` | Versionado del bucket | Versionado habilitado para historial de estados |
| `aws_s3_bucket_server_side_encryption_configuration` | Encriptación del bucket | Encriptación AES256 para seguridad |
| `aws_s3_bucket_public_access_block` | Bloqueo de acceso público | Bloquea todo acceso público al bucket |
| `aws_dynamodb_table.terraform_locks` | Tabla DynamoDB para locks | Modo PAY_PER_REQUEST, clave primaria: LockID |

**Configuración del Bucket S3**:
- **Nombre**: `genius-terraform-state-{region}` (único globalmente)
- **Versionado**: Habilitado para mantener historial de estados
- **Encriptación**: AES256 (server-side encryption)
- **Acceso público**: Bloqueado completamente
- **Lifecycle**: Configurable (por defecto sin expiración)

**Configuración de DynamoDB**:
- **Nombre de tabla**: `terraform-locks`
- **Modo**: PAY_PER_REQUEST (sin capacidad reservada, paga por uso)
- **Clave primaria**: `LockID` (String)
- **Propósito**: Prevenir modificaciones concurrentes del estado (state locking)

**Cómo usar**:

1. **Primera vez** (crear el backend):
   ```bash
   cd infra/backend-setup
   terraform init
   terraform plan
   terraform apply
   ```

2. **Migrar ambientes al backend remoto**:
   ```bash
   cd infra/envs/dev  # (o qa, prod)
   terraform init -migrate-state
   ```

3. **Verificar migración**:
   ```bash
   terraform state list  # Debe mostrar todos los recursos
   ```

**Seguridad**:
- ✅ Bucket S3 con acceso público bloqueado
- ✅ Encriptación automática del estado
- ✅ State locking para prevenir conflictos
- ✅ Versionado para recuperación de estados anteriores
- ⚠️ Los recursos tienen `prevent_destroy = true` por defecto para evitar eliminaciones accidentales

### 9. Configuración por Ambiente (`infra/envs/{dev|qa|prod}/`)

Cada ambiente tiene su propia configuración que orquesta todos los módulos:

#### **main.tf** - Orquestación de Módulos
```hcl
1. Módulo VPC
   ↓ Outputs: vpc_id, subnet_ids, etc.
2. Módulo Security Groups (usa outputs de VPC)
   ↓ Outputs: security_group_ids
3. Data Source: aws_ami (obtiene AMI más reciente si no se especifica)
4. Módulo Secrets Manager (crea secretos de BD, API keys, genéricos)
   ↓ Outputs: secret ARNs, secret names
5. Módulo ALB (usa outputs de VPC y Security Groups)
   ↓ Outputs: target_group_arn, alb_arn
6. Módulo Autoscaling (usa outputs anteriores + secret ARNs para permisos)
   ↓ Outputs: autoscaling_group_name
7. Módulo CloudWatch (usa outputs de ALB y Autoscaling)
   ↓ Outputs: alarm ARNs, dashboard URL
```

#### **variables.tf** - Variables del Ambiente
Define todas las variables necesarias para el ambiente, incluyendo:
- Variables de red (VPC, subredes, AZs)
- Variables de configuración de módulos
- Variables específicas del ambiente
- Variables de Secrets Manager (credenciales de BD, API keys, secretos genéricos)
- Variables de KMS para cifrado de secretos (opcional)

#### **terraform.tfvars** - Valores Específicos
Contiene los valores reales para cada ambiente. Ejemplo para dev:
```hcl
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
instance_type = "t3.micro"
min_size = 1
desired_capacity = 2
max_size = 5
```

#### **provider.tf** - Configuración del Provider
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

#### **outputs.tf** - Outputs del Ambiente
Exporta información útil después del despliegue:
- DNS del ALB
- IDs de VPC y subredes
- Nombres de recursos importantes
- ARNs y nombres de secretos de Secrets Manager

## Flujo de Integración entre Módulos

El siguiente diagrama muestra cómo los módulos se integran y dependen unos de otros:

```
┌─────────────────────────────────────────────────────────────┐
│                    Módulo VPC                                │
│  Outputs: vpc_id, public_subnet_ids, private_subnet_ids    │
└───────────────┬─────────────────────────────────────────────┘
                │
                ├──────────────────────────────────┐
                │                                  │
                ▼                                  ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Módulo Security Groups      │    │     Data Source aws_ami      │
│  Inputs: vpc_id              │    │  (obtiene AMI si no especif.) │
│  Outputs: alb_sg_id,         │    └──────────────┬───────────────┘
│            app_sg_id         │                   │
└──────────────┬───────────────┘                   │
               │                                   │
               │                                   │
               ▼                                   │
┌──────────────────────────────┐                   │
│     Módulo ALB               │                   │
│  Inputs: vpc_id,             │                   │
│          public_subnet_ids,  │                   │
│          [alb_sg_id]         │                   │
│  Outputs: target_group_arn   │                   │
└──────────────┬───────────────┘                   │
               │                                   │
                └───────────────┬───────────────────┘
                               │
                               ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│     Módulo ALB               │    │  Módulo Secrets Manager      │
│  Inputs: vpc_id,             │    │  Inputs: project_name,       │
│          public_subnet_ids,  │    │          environment,        │
│          [alb_sg_id]         │    │          db credentials,     │
│  Outputs: target_group_arn   │    │          api_keys, etc.      │
└──────────────┬───────────────┘    │  Outputs: secret ARNs,       │
               │                    │          secret names        │
                └───────────────┬───┴───────────────┬───────────────┘
                               │                   │
                               ▼                   ▼
                ┌──────────────────────────────────────────────┐
                │   Módulo Autoscaling                         │
                │  Inputs: ami_id (o data),                    │
                │          subnet_ids (priv),                  │
                │          [app_sg_id],                        │
                │          target_group_arn,                   │
                │          secrets_manager_arns  ←─────────────┤
                │          secrets_manager_secret_names        │
                │  Outputs: asg_name, etc.                     │
                └──────────────┬───────────────┘
                               │
                               │
                               ▼
                ┌──────────────────────────────┐
                │   Módulo CloudWatch          │
                │  Inputs: alb_arn,            │
                │          target_group_arn,   │
                │          asg_name            │
                │  Outputs: alarm ARNs,        │
                │          dashboard URL       │
                └──────────────────────────────┘
```

## Flujo de Datos y Tráfico

El siguiente diagrama muestra el flujo completo de tráfico de datos desde Internet hasta las instancias de la aplicación:

```
Internet (0.0.0.0/0)
  ↓ [HTTP/HTTPS - Puertos 80/443]
Application Load Balancer (ALB)
  ├─ Ubicación: Subredes Públicas (AZ-1a y AZ-1b)
  ├─ Security Group: alb-sg
  │   └─ Permite: 80/443 desde Internet
  └─ Health Checks: Ruta configurable (default: /)
      ↓ [HTTP - Puerto 8080]
Target Group (ALB)
  ├─ Protocolo: HTTP
  ├─ Puerto: 8080 (configurable)
  └─ Health Check: Configurable
      ↓ [Reglas: Solo desde alb-sg]
Auto Scaling Group (ASG)
  ├─ Ubicación: Subredes Privadas (AZ-1a y AZ-1b)
  ├─ Security Group: app-sg
  │   └─ Permite: Puerto app SOLO desde alb-sg ⚠️
  └─ Instancias: 1-20 según carga (min/desired/max)
      ↓ [Instancias EC2]
EC2 Instances
  ├─ Configuración: Launch Template
  ├─ User Data: Script de inicialización
  ├─ Acceso a Internet: Vía NAT Gateway (sin IP público)
  └─ Aplicación: Puerto 8080 (configurable)
```

### Puntos Críticos de Seguridad

1. **Aislamiento de Instancias**: Las instancias EC2 están en subredes privadas y NO tienen IP público
2. **Principio de Mínimo Acceso**: El `app-sg` solo acepta tráfico desde `alb-sg`, no desde Internet directamente
3. **Salida Controlada**: Las instancias acceden a Internet solo vía NAT Gateway
4. **Multi-AZ**: Alta disponibilidad con instancias en múltiples zonas de disponibilidad

## Configuración por Ambiente

### Desarrollo (dev)

**Red:**
- VPC CIDR: `10.0.0.0/16`
- Subredes públicas: `10.0.1.0/24` (us-east-1a), `10.0.2.0/24` (us-east-1b)
- Subredes privadas: `10.0.10.0/24` (us-east-1a), `10.0.20.0/24` (us-east-1b)
- 2 NAT Gateways (uno por AZ)

**Aplicación:**
- Puerto app: `8080`
- Instance Type: `t3.micro`
- Auto Scaling: min=1, desired=2, max=5
- HTTPS: Deshabilitado (solo HTTP)
- Deletion Protection: Desactivado

**Base de Datos:**
- Puerto DB: `3306` (MySQL)

**Secrets Manager:**
- Configuración de secretos disponible pero deshabilitada por defecto
- Para habilitar: Ver `infra/GUIA_SECRETS_MANAGER.md`
- Ejemplo de configuración comentada en `terraform.tfvars`

**Secrets Manager:**
- Configuración de secretos disponible pero deshabilitada por defecto
- Para habilitar: Ver `infra/GUIA_SECRETS_MANAGER.md`
- Ejemplo de configuración comentada en `terraform.tfvars`

### QA (Quality Assurance)

**Red:**
- VPC CIDR: `10.1.0.0/16`
- Subredes públicas: `10.1.1.0/24` (us-east-1a), `10.1.2.0/24` (us-east-1b)
- Subredes privadas: `10.1.10.0/24` (us-east-1a), `10.1.20.0/24` (us-east-1b)
- 2 NAT Gateways (uno por AZ)

**Aplicación:**
- Puerto app: `8080`
- Instance Type: `t3.small`
- Auto Scaling: min=2, desired=2, max=10
- HTTPS: Deshabilitado por defecto (configurable)
- Deletion Protection: Desactivado

**Base de Datos:**
- Puerto DB: `3306` (MySQL)

**Secrets Manager:**
- Configuración de secretos disponible pero deshabilitada por defecto
- Para habilitar: Ver `infra/GUIA_SECRETS_MANAGER.md`
- Ejemplo de configuración comentada en `terraform.tfvars`

### Producción (prod)

**Red:**
- VPC CIDR: `10.2.0.0/16`
- Subredes públicas: `10.2.1.0/24` (us-east-1a), `10.2.2.0/24` (us-east-1b)
- Subredes privadas: `10.2.10.0/24` (us-east-1a), `10.2.20.0/24` (us-east-1b)
- 2 NAT Gateways (uno por AZ)

**Aplicación:**
- Puerto app: `8080`
- Instance Type: `t3.medium`
- Auto Scaling: min=2, desired=3, max=20
- HTTPS: Habilitado por defecto (requiere certificate_arn)
- Deletion Protection: **Activado** (protección contra eliminación accidental)
- Health Check Path: `/health` (más estricto que dev/qa)

**Base de Datos:**
- Puerto DB: `3306` (MySQL)

**Secrets Manager:**
- Configuración de secretos disponible pero deshabilitada por defecto
- Para habilitar: Ver `infra/GUIA_SECRETS_MANAGER.md`
- Ejemplo de configuración comentada en `terraform.tfvars`

## Requisitos Previos

1. **Terraform >= 1.0** instalado
2. **AWS CLI** configurado con credenciales
3. **Permisos IAM** en AWS para crear:
   - VPC, Subnets, Internet Gateway, NAT Gateway
   - Elastic IPs, Route Tables
   - Security Groups y reglas de seguridad

### Configurar AWS CLI
```bash
aws configure
# Ingresa tu AWS Access Key ID
# Ingresa tu AWS Secret Access Key
# Región: us-east-1 (o la que prefieras)
# Formato de salida: json
```

## Despliegue en AWS

### Paso 0: Configurar Backend Remoto (Primera vez, opcional pero recomendado)

Si es la primera vez o quieres usar backend remoto para compartir estado entre equipo:

```bash
# 1. Crear el backend (bucket S3 + tabla DynamoDB)
cd infra/backend-setup
terraform init
terraform plan
terraform apply

# 2. Migrar el estado de cada ambiente al backend remoto
cd ../envs/dev  # (o qa, prod)
terraform init -migrate-state
```

**Nota**: Si trabajas solo o es un proyecto pequeño, puedes omitir este paso y usar backend local.

### Paso 1: Configurar la región (opcional)
Edita `infra/envs/{ambiente}/terraform.tfvars` si quieres cambiar la región o valores de red.

### Paso 2: Inicializar Terraform
```bash
cd infra/envs/dev  # (o qa, prod)
terraform init
```

### Paso 3: Verificar el plan
```bash
terraform plan
```
Esto mostrará todos los recursos que se crearán en AWS (incluyendo VPC, Security Groups, ALB, ASG, CloudWatch).

### Paso 4: Aplicar la configuración
```bash
terraform apply
```
Confirma con `yes` cuando se solicite.

### Paso 5: Verificar el despliegue
```bash
# Ver outputs del despliegue (DNS del ALB, IDs de recursos, etc.)
terraform output

# O ver recursos específicos en la consola de AWS:
# - VPC: https://console.aws.amazon.com/vpc/
# - ALB: https://console.aws.amazon.com/ec2/v2/home#LoadBalancers:
# - Auto Scaling Groups: https://console.aws.amazon.com/ec2autoscaling/home
# - CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home#dashboards:
# - CloudWatch Alarms: https://console.aws.amazon.com/cloudwatch/home#alarmsV2:
```

## Comandos Útiles

```bash
# Ver el estado actual
terraform show

# Ver outputs
terraform output

# Destruir la infraestructura (¡cuidado!)
terraform destroy

# Validar configuración
terraform validate

# Formatear código
terraform fmt
```

## Despliegue por Ambiente

### Desarrollo
```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

### QA
```bash
cd infra/envs/qa
terraform init
terraform plan
terraform apply
```

### Producción
```bash
cd infra/envs/prod
terraform init
terraform plan
terraform apply
```

## Notas Importantes

### ⚠️ Costos y Recursos

- **NAT Gateways**: Tienen costo por hora (~$0.045/hora) y por datos transferidos (~$0.045/GB)
- **Elastic IPs**: Se crearán 2 EIPs (una por NAT Gateway) - gratis mientras estén en uso
- **Application Load Balancer**: Costo por hora (~$0.0225/hora) y por datos procesados
- **EC2 Instances**: Costo variable según tipo y cantidad (ej: t3.micro ~$0.0104/hora)
- **Total estimado para dev**: ~$50-100/mes (con 2 instancias t3.micro corriendo)
- **Total estimado para prod**: ~$200-500/mes (según carga y cantidad de instancias)

### 🔒 Seguridad y Configuración

- **Backend de Terraform**: Usa estado local por defecto. **Recomendado**: Configurar backend remoto en S3 para producción
- **Tagging**: Todos los recursos están etiquetados con `Project: genius` y `Environment: {dev|qa|prod}`
- **Deletion Protection**: Activado en producción, desactivado en dev/qa
- **Key Pairs**: Si no especificas `key_name`, las instancias no tendrán clave SSH configurada

### 📋 Recursos Creados por Ambiente

Al ejecutar `terraform apply` en cualquier ambiente, se crearán:

**Red:**
- 1 VPC
- 2 Subredes públicas
- 2 Subredes privadas
- 1 Internet Gateway
- 2 NAT Gateways
- 2 Elastic IPs
- 1 Tabla de ruteo pública
- 2 Tablas de ruteo privadas

**Seguridad:**
- 3-6 Security Groups (alb-sg, app-sg, db-sg, y opcionales: web-sg, redis-sg, bastion-sg)

**Aplicación:**
- 1 Application Load Balancer
- 1 Target Group
- 1-2 Listeners (HTTP y opcional HTTPS)
- 1 Launch Template
- 1 Auto Scaling Group
- 1-20 Instancias EC2 (según configuración del ASG)
- 2 Políticas de escalado (scale up/down)

### 🎯 Consideraciones por Ambiente

**Desarrollo:**
- Menor costo: instancias pequeñas, menor capacidad
- HTTPS deshabilitado por defecto
- Deletion protection desactivado (fácil limpieza)

**QA:**
- Configuración intermedia
- Puede habilitar HTTPS para pruebas
- Deletion protection desactivado

**Producción:**
- Configuración robusta: instancias medianas/grandes
- HTTPS habilitado por defecto (requiere certificate_arn)
- Deletion protection activado
- Health checks más estrictos

## Cómo Entender y Trabajar con el Código Terraform

### Orden de Lectura Recomendado

Para entender completamente cómo está constituido el Terraform, te recomendamos leer los archivos en este orden:

1. **Empieza con un ambiente** (ej: `infra/envs/dev/`):
   - `provider.tf` - Entiende la configuración del provider AWS
   - `variables.tf` - Ve qué variables se requieren
   - `terraform.tfvars` - Observa los valores reales utilizados
   - `main.tf` - Comprende cómo se orquestan los módulos

2. **Luego revisa los módulos en orden de dependencia**:
   - `modules/vpc/` - Infraestructura de red base
   - `modules/security_groups/` - Reglas de seguridad
   - `modules/alb/` - Load balancer
   - `modules/autoscaling/` - Auto scaling y instancias

3. **Para cada módulo, lee en este orden**:
   - `variables.tf` - Entradas del módulo
   - `main.tf` - Recursos creados
   - `outputs.tf` - Valores exportados

### Ejemplo: Seguir el Flujo de un Cambio

Supongamos que quieres cambiar el tipo de instancia. Aquí está el flujo:

```
1. Edita: infra/envs/dev/terraform.tfvars
   - Cambia: instance_type = "t3.small"

2. Este valor se pasa a: infra/envs/dev/main.tf
   - En el módulo autoscaling: instance_type = var.instance_type

3. El módulo autoscaling recibe: modules/autoscaling/variables.tf
   - variable "instance_type" { ... }

4. Se usa en: modules/autoscaling/main.tf
   - aws_launch_template.app { instance_type = var.instance_type }

5. Al ejecutar terraform apply:
   - El ASG actualizará las instancias existentes o creará nuevas
   - Las instancias existentes seguirán con el tipo anterior hasta que se reemplacen
```

### Conceptos Clave del Código

#### 1. Módulos como Funciones

Los módulos Terraform son como funciones en programación:
- **Inputs** (`variables.tf`): Parámetros que recibe el módulo
- **Procesamiento** (`main.tf`): Recursos que crea el módulo
- **Outputs** (`outputs.tf`): Valores que devuelve el módulo

Ejemplo: El módulo VPC recibe CIDRs y zonas de disponibilidad, y devuelve IDs de VPC y subredes.

#### 2. Dependencias entre Módulos

Los módulos dependen unos de otros mediante outputs e inputs:

```hcl
# En main.tf del ambiente:
module "vpc" {
  # ...
}

module "security_groups" {
  vpc_id = module.vpc.vpc_id  # ← Output de VPC como input de Security Groups
}

module "alb" {
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_security_group_id]
}

module "autoscaling" {
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.app_security_group_id]
  target_group_arns = [module.alb.target_group_arn]
}
```

#### 3. Data Sources

Los data sources permiten obtener información de AWS sin crear recursos:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  # Filtros para encontrar la AMI correcta
}
```

Esto es útil cuando quieres usar recursos existentes o obtener la última versión de algo.

#### 4. Variables y Valores

- **`variables.tf`**: Define qué variables acepta un módulo/ambiente
- **`terraform.tfvars`**: Asigna valores específicos a esas variables
- **Valores por defecto**: En `variables.tf`, puedes usar `default = "valor"`

#### 5. Outputs

Los outputs permiten exportar información útil después del despliegue:

```bash
# Después de terraform apply, puedes ver:
terraform output alb_dns_name
# Output: genius-dev-alb-123456789.us-east-1.elb.amazonaws.com
```

### Trabajar con Múltiples Ambientes

Cada ambiente (dev, qa, prod) es **independiente**:
- Tiene su propio estado de Terraform
- Puede usar valores diferentes
- Puede desplegarse por separado

**Estructura recomendada**:
```
infra/envs/dev/terraform.tfvars   # Valores para desarrollo
infra/envs/qa/terraform.tfvars    # Valores para QA
infra/envs/prod/terraform.tfvars  # Valores para producción
```

**Comparten**:
- Los mismos módulos (`infra/modules/`)
- La misma estructura de variables
- Las mismas buenas prácticas

## Configuración Avanzada de Security Groups

### Habilitar SSH para acceso remoto

Edita `infra/envs/{ambiente}/terraform.tfvars`:

```hcl
enable_ssh = true
allowed_ssh_cidrs = ["203.0.113.0/24"]  # Tu IP o rango de IPs de oficina/VPN
```

### Cambiar puerto de base de datos

Para PostgreSQL:
```hcl
db_port   = 5432
db_engine = "postgres"
```

Para MongoDB:
```hcl
db_port   = 27017
db_engine = "mongodb"
```

### Habilitar Redis/ElastiCache

```hcl
enable_redis = true
```

### Restringir acceso web a IPs específicas

En `infra/envs/{ambiente}/variables.tf` agrega:
```hcl
variable "allowed_web_cidrs" {
  type = list(string)
  default = ["203.0.113.0/24"]  # Solo desde esta IP
}
```

Y en `main.tf` del módulo security_groups, pasa la variable:
```hcl
allowed_web_cidrs = var.allowed_web_cidrs
```

## Características y Buenas Prácticas Implementadas

### ✅ Modularidad
- Cada componente (VPC, Security Groups, ALB, ASG) está en su propio módulo
- Módulos reutilizables entre ambientes (dev, qa, prod)
- Fácil mantenimiento y actualización

### ✅ Seguridad
- **Instancias en subredes privadas**: Sin exposición directa a Internet
- **Security Groups con mínimo acceso**: Solo tráfico necesario
- **NAT Gateway**: Acceso saliente controlado
- **Principio de menor privilegio**: Cada Security Group solo permite lo esencial

### ✅ Alta Disponibilidad
- Múltiples zonas de disponibilidad (al menos 2 AZs)
- NAT Gateways redundantes (uno por AZ)
- Auto Scaling para mantener disponibilidad durante picos de carga

### ✅ Escalabilidad
- Auto Scaling configurable por ambiente
- Health checks automáticos para detectar instancias no saludables
- Políticas de escalado automático (scale up/down)

### ✅ Gestión de Estado
- Estado de Terraform versionado con backend remoto (S3 + DynamoDB)
- Tagging consistente en todos los recursos
- Outputs claros para integración con otros sistemas

### ✅ Monitoreo y Observabilidad
- CloudWatch Dashboard con métricas clave (Healthy Hosts, Request Count, Response Time, CPU)
- Alarmas configuradas para instancias no saludables, errores 5xx y CPU alto
- Métricas automáticas de ALB y EC2 sin configuración adicional

### ✅ Gestión de Secretos
- AWS Secrets Manager integrado para almacenamiento seguro de credenciales
- Cifrado automático con KMS (clave por defecto o personalizada)
- Descarga automática de secretos en instancias EC2 al iniciar
- Soporte para credenciales de BD, API keys y secretos genéricos
- Integración IAM con permisos granulares (solo lectura de secretos específicos)

### ✅ Optimizaciones de Destroy
- Timeouts configurados en todos los recursos críticos para evitar bloqueos
- Dependencias explícitas (`depends_on`) para orden correcto de destrucción
- Destroy Protection deshabilitado en dev/qa para destroy rápido
- Destroy de NAT Gateway optimizado (reducido de ~20min a ~5-10min)

## Componentes Opcionales y Futuras Mejoras

### Componentes Actualmente Disponibles pero No Desplegados

1. **RDS Database** - Security Group `db-sg` está disponible para futuras bases de datos
2. **Redis/ElastiCache** - Security Group `redis-sg` disponible si se necesita cache
3. **Bastion Host** - Security Group `bastion-sg` disponible para acceso SSH seguro

### Componentes Ya Implementados ✅

1. ✅ **Backend S3 + DynamoDB**: Backend remoto configurado (`infra/backend-setup/`)
2. ✅ **CloudWatch Alarms y Dashboard**: Monitoreo completo implementado (`infra/modules/cloudwatch/`)
3. ✅ **Optimizaciones de Destroy**: Timeouts y dependencias configuradas en ALB y VPC
4. ✅ **AWS Secrets Manager**: Gestión segura de secretos implementada (`infra/modules/secrets-manager/`)
   - Secreto de credenciales de base de datos
   - Secreto de API keys
   - Secretos genéricos personalizables
   - Integración automática con instancias EC2

### Mejoras Futuras Recomendadas

1. **SSL/TLS**: Configurar certificados ACM y habilitar HTTPS en producción (certificate_arn ya soportado)
2. **WAF**: Agregar AWS WAF al ALB para protección adicional contra ataques
3. **RDS**: Desplegar base de datos RDS/Aurora usando el `db-sg` ya creado (puede usar Secrets Manager para credenciales)
4. **Rotación de Secretos**: Habilitar rotación automática de secretos en Secrets Manager (requiere Lambda function)
4. **CI/CD**: Integrar con pipelines de CI/CD (ya hay estructura en `.github/workflows/`)
5. **Application Logs**: Configurar CloudWatch Logs para logs de aplicación (más allá de métricas)
6. **Backup**: Implementar estrategias de backup para datos críticos (RDS, S3, etc.)
7. **SNS Notifications**: Configurar notificaciones SNS para las alarmas de CloudWatch
8. **Auto Scaling basado en métricas**: Conectar alarmas de CloudWatch con políticas de Auto Scaling

## Troubleshooting

### Problemas Comunes

1. **Las instancias no reciben tráfico del ALB**
   - Verificar que el `app-sg` permite tráfico desde `alb-sg`
   - Verificar que las instancias están en el Target Group del ALB
   - Verificar health checks del Target Group

2. **Las instancias no pueden acceder a Internet**
   - Verificar que las subredes privadas tienen tablas de ruteo con NAT Gateway
   - Verificar que el NAT Gateway está en estado "Available"
   - Verificar que las instancias tienen el `app-sg` con egress permitido

3. **Error al crear el Launch Template**
   - Verificar que el AMI ID existe en la región correcta
   - Verificar que la clave SSH (si se especifica) existe en AWS
   - Verificar que el tipo de instancia está disponible en la región

4. **El ALB no es accesible desde Internet**
   - Verificar que el ALB está en subredes públicas
   - Verificar que el `alb-sg` permite tráfico desde Internet (0.0.0.0/0)
   - Verificar que el Internet Gateway está correctamente configurado

5. **Terraform destroy se demora mucho o falla**
   - Verificar que `enable_deletion_protection = false` en el módulo ALB
   - Verificar que los timeouts están configurados correctamente
   - Verificar que no hay ENIs (Elastic Network Interfaces) colgados
   - Si hay error "Network has some mapped public address(es)": Los `depends_on` deberían resolverlo automáticamente

6. **Error "Network has some mapped public address(es)" al destruir VPC**
   - Este error ya está resuelto con las dependencias explícitas (`depends_on`)
   - Asegúrate de que los NAT Gateways se destruyen antes que el Internet Gateway
   - Los timeouts configurados deberían prevenir este problema

## Optimizaciones de Destroy - Detalles Técnicos

### Problemas Resueltos

Este proyecto implementa optimizaciones específicas para resolver problemas comunes durante `terraform destroy`:

#### 1. Error del Internet Gateway
**Problema**: AWS bloquea la destrucción del Internet Gateway si hay direcciones IP públicas (EIPs) asociadas a NAT Gateways.

**Solución**:
- `depends_on` explícito en Elastic IPs y NAT Gateways hacia el Internet Gateway
- Orden correcto de destrucción: NAT Gateways → EIPs → Route Tables → Internet Gateway

#### 2. ENIs (Elastic Network Interfaces) Colgados
**Problema**: Interfaces de red que quedan asociadas y bloquean la destrucción.

**Solución**:
- Dependencias explícitas (`depends_on`) en Target Groups y Listeners del ALB
- Orden correcto: Listeners → Target Groups → ALB

#### 3. Destroy de 20 minutos
**Problema**: NAT Gateways pueden tardar mucho en destruirse sin timeouts adecuados.

**Solución**:
- Timeouts configurados en NAT Gateway: `delete: 10m` (reduce de ~20min a ~5-10min)
- Timeouts en todos los recursos críticos para evitar bloqueos

### Configuraciones Aplicadas

#### Módulo ALB (`infra/modules/alb/main.tf`)
```hcl
resource "aws_lb" "main" {
  enable_deletion_protection = false  # Siempre false para destroy rápido
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "15m"
  }
}

resource "aws_lb_target_group" "app" {
  depends_on = [aws_lb.main]  # Dependencia explícita
}

resource "aws_lb_listener" "http" {
  depends_on = [aws_lb.main, aws_lb_target_group.app]  # Orden correcto
}
```

#### Módulo VPC (`infra/modules/vpc/main.tf`)
```hcl
resource "aws_vpc" "main" {
  timeouts {
    create = "10m"
    delete = "15m"
  }
}

resource "aws_internet_gateway" "main" {
  timeouts {
    create = "5m"
    delete = "10m"
  }
}

resource "aws_nat_gateway" "main" {
  timeouts {
    create = "10m"
    delete = "10m"  # Reduce destroy de ~20min a ~5-10min
  }
  depends_on = [aws_internet_gateway.main]  # Orden correcto
}

resource "aws_eip" "nat" {
  timeouts {
    read   = "5m"
    delete = "10m"
  }
  depends_on = [aws_internet_gateway.main]  # Evita error de IPs mapeadas
}
```

### Resultados Esperados

- ✅ Destroy completo de infraestructura: **~5-15 minutos** (antes: ~20-30 minutos)
- ✅ Sin errores de "Network has some mapped public address(es)"
- ✅ Sin ENIs colgados
- ✅ Destroy sin intervención manual

### Notas Importantes

- Estas optimizaciones son **solo en código Terraform**, no requieren cambios en el pipeline
- Los timeouts son conservadores pero evitan bloqueos indefinidos
- Las dependencias explícitas aseguran el orden correcto sin depender del orden implícito de Terraform

## Configuración del Launch Template - Resumen

### ¿Qué sistema usar (AMI)?

**Amazon Linux 2** - La AMI más reciente disponible automáticamente.

- **Tipo**: `amzn2-ami-hvm-*-x86_64-gp2`
- **Virtualización**: HVM (Hardware Virtual Machine)
- **Arquitectura**: x86_64
- **Almacenamiento**: GP2 (SSD)
- **Selección automática**: Si no se especifica un `ami_id` en `terraform.tfvars`, Terraform busca y usa automáticamente la AMI más reciente de Amazon Linux 2
- **Propietario**: Amazon (ID: amazon)

### ¿Qué tamaño de servidor?

**t3.micro**

- **Tipo de instancia**: `t3.micro`
- **Características**:
  - 2 vCPUs
  - 1 GB de RAM
  - Rendimiento de red: Hasta 5 Gbps
  - Ideal para: Desarrollo, pruebas y cargas de trabajo ligeras
- **Configuración**: Definido en `terraform.tfvars` con valor por defecto `t3.micro`
- **Personalizable**: Se puede cambiar modificando `instance_type` en `terraform.tfvars`

### ¿Qué reglas de seguridad (Security Groups)?

**Security Group: `app-sg`** (`${project_name}-${environment}-app-sg`)

#### Reglas de Entrada (Ingress):

1. **Puerto de la aplicación desde ALB**:
   - Puerto: `8080` (configurable mediante `app_port`)
   - Protocolo: TCP
   - Origen: Security Group del ALB (`alb-sg`)
   - Propósito: Permite que el Application Load Balancer envíe tráfico a las instancias

2. **SSH (Opcional)**:
   - Puerto: `22`
   - Protocolo: TCP
   - Origen: IPs específicas definidas en `allowed_ssh_cidrs` (solo si `enable_ssh = true`)
   - Propósito: Acceso remoto SSH para administración

3. **Comunicación entre instancias**:
   - Puerto: `8080` (configurable mediante `app_port`)
   - Protocolo: TCP
   - Origen: Mismo security group (`self = true`)
   - Propósito: Permite comunicación entre instancias de la aplicación

#### Reglas de Salida (Egress):

- **Todo el tráfico saliente**:
  - Puertos: `0-65535` (todos)
  - Protocolo: Todos (`-1`)
  - Destino: `0.0.0.0/0` (Internet)
  - Propósito: Permite a las instancias acceder a Internet (para actualizaciones, descargas, etc.)

### ¿Qué hacer al arrancar?

El script `user_data.sh` se ejecuta automáticamente cuando la instancia inicia por primera vez. Realiza las siguientes acciones en orden:

1. **Actualizar el sistema**:
   ```bash
   yum update -y
   ```
   - Actualiza todos los paquetes del sistema operativo a la última versión disponible
   - El flag `-y` acepta automáticamente todas las actualizaciones sin confirmación

2. **Instalar Docker**:
   ```bash
   yum install -y docker
   ```
   - Instala Docker Engine en la instancia EC2
   - Necesario para ejecutar contenedores

3. **Iniciar y habilitar Docker**:
   ```bash
   systemctl start docker
   systemctl enable docker
   ```
   - `start`: Inicia el servicio Docker inmediatamente
   - `enable`: Configura Docker para iniciar automáticamente al arrancar la instancia

4. **Levantar una app (nginx) en el puerto 8080**:
   ```bash
   docker run -d --name app --restart always -p 8080:8080 nginx:alpine
   ```
   - `-d`: Ejecuta el contenedor en modo detached (background)
   - `--name app`: Asigna el nombre "app" al contenedor
   - `--restart always`: Reinicia automáticamente el contenedor si se detiene o falla
   - `-p 8080:8080`: Mapea el puerto 8080 del host al puerto 8080 del contenedor
   - `nginx:alpine`: Imagen Docker de Nginx (versión ligera Alpine Linux)
   - **Nota**: El puerto se configura mediante la variable `app_port` (por defecto: 8080)

5. **Registro de log**:
   ```bash
   echo "Aplicación iniciada en el puerto 8080" >> /var/log/user-data.log
   ```
   - Registra un mensaje de confirmación en el log
   - Útil para verificar que la aplicación se inició correctamente

#### Ubicación del Script:
- Archivo: `infra/modules/autoscaling/user_data.sh`
- Codificación: Se codifica en base64 antes de enviarse a AWS
- Ejecución: Automática al iniciar cada nueva instancia del Auto Scaling Group

## Auto Scaling Group - Configuración de Servidores

### ¿Cuántos servidores deben existir?

El Auto Scaling Group mantiene un número variable de servidores según la configuración:

| Parámetro | Valor (Dev) | Descripción |
|-----------|-------------|-------------|
| **Mínimo** (`min_size`) | **1 servidor** | Número mínimo de instancias que siempre deben estar ejecutándose |
| **Deseado** (`desired_capacity`) | **2 servidores** | Número objetivo de instancias que el ASG intenta mantener |
| **Máximo** (`max_size`) | **5 servidores** | Número máximo de instancias que el ASG puede crear |

**Configuración actual (ambiente dev):**
- **Mínimo**: 1 instancia (garantiza disponibilidad básica)
- **Deseado**: 2 instancias (distribución balanceada entre AZs)
- **Máximo**: 5 instancias (permite escalar bajo carga)

**Nota**: Estos valores son configurables en `terraform.tfvars` y varían según el ambiente:
- **Dev**: min=1, desired=2, max=5
- **QA**: min=2, desired=2, max=10
- **Prod**: min=2, desired=3, max=20

### ¿En qué subredes se crean?

**Subredes Privadas** - Las instancias se crean en subredes privadas para mayor seguridad.

**Configuración (ambiente dev):**
- **Subred Privada 1**: `10.0.10.0/24` (us-east-1a)
- **Subred Privada 2**: `10.0.20.0/24` (us-east-1b)

**Características:**
- ✅ **Sin IPs públicas**: Las instancias no tienen acceso directo desde Internet
- ✅ **Acceso a Internet vía NAT Gateway**: Salida controlada a través de NAT Gateway
- ✅ **Seguridad mejorada**: Solo reciben tráfico desde el ALB (a través de security groups)
- ✅ **Aislamiento**: No son accesibles directamente desde Internet

**Configuración en Terraform:**
```hcl
subnet_ids = module.vpc.private_subnet_ids  # ASG en subredes privadas
```

### ¿En qué zonas (AZ A y AZ B)?

**Distribución Multi-AZ** - Las instancias se distribuyen automáticamente entre múltiples zonas de disponibilidad.

**Zonas de Disponibilidad configuradas:**
- **AZ A**: `us-east-1a`
  - Subred privada: `10.0.10.0/24`
  - NAT Gateway: Uno por AZ para alta disponibilidad
  
- **AZ B**: `us-east-1b`
  - Subred privada: `10.0.20.0/24`
  - NAT Gateway: Uno por AZ para alta disponibilidad

**Distribución automática:**
- AWS Auto Scaling Group distribuye las instancias **equitativamente** entre las zonas disponibles
- Con `desired_capacity = 2` y 2 AZs:
  - **1 instancia en us-east-1a** (Subred `10.0.10.0/24`)
  - **1 instancia en us-east-1b` (Subred `10.0.20.0/24`)

**Ventajas de Multi-AZ:**
- ✅ **Alta Disponibilidad**: Si una AZ falla, las instancias en la otra AZ siguen funcionando
- ✅ **Tolerancia a Fallos**: Protección contra fallos a nivel de zona de disponibilidad
- ✅ **Balanceo de Carga**: El ALB distribuye el tráfico entre instancias en ambas AZs
- ✅ **Resiliencia**: La aplicación sigue disponible incluso si una AZ completa se cae

### ¿Qué pasa si uno se cae?

**Reemplazo Automático** - El Auto Scaling Group detecta y reemplaza automáticamente instancias no saludables.

#### 1. **Detección de Instancias No Saludables**

**Health Check Type: ELB**
- El ASG usa el health check del **Application Load Balancer (ALB)**
- El ALB verifica periódicamente que las instancias respondan correctamente
- Si una instancia falla el health check, el ALB la marca como "unhealthy"

**Proceso de Health Check:**
```
ALB → Health Check → Instancia EC2
  ├─ Éxito: Instancia saludable ✅
  └─ Falla: Instancia no saludable ❌ → ASG la reemplaza
```

#### 2. **Reemplazo Automático**

Cuando una instancia se marca como no saludable:

1. **Detección**: El ALB detecta que la instancia no responde
2. **Marcado**: El ASG marca la instancia como "unhealthy"
3. **Terminación**: El ASG termina la instancia no saludable
4. **Creación**: El ASG crea una nueva instancia usando el Launch Template
5. **Inicialización**: La nueva instancia ejecuta el `user_data.sh` automáticamente
6. **Registro**: La nueva instancia se registra en el Target Group del ALB
7. **Verificación**: El ALB verifica que la nueva instancia esté saludable

**Tiempo estimado**: 2-5 minutos desde la detección hasta que la nueva instancia esté lista

#### 3. **Mantenimiento de Capacidad Deseada**

El ASG **siempre** mantiene el número de instancias en `desired_capacity`:
- Si una instancia se cae y `desired_capacity = 2`:
  - El ASG detecta que solo hay 1 instancia saludable
  - Crea automáticamente una nueva instancia para volver a 2
  - La nueva instancia se distribuye en la AZ disponible

#### 4. **Escenarios de Fallo**

**Escenario A: Fallo de una instancia individual**
- ✅ El ASG detecta el fallo vía health check del ALB
- ✅ Termina la instancia no saludable
- ✅ Crea una nueva instancia en la misma o diferente AZ
- ✅ El servicio continúa funcionando sin interrupción

**Escenario B: Fallo de una zona de disponibilidad completa**
- ✅ Las instancias en la AZ afectada se marcan como no saludables
- ✅ El ASG crea nuevas instancias en la AZ que sigue funcionando
- ✅ El ALB redirige todo el tráfico a las instancias saludables
- ✅ El servicio continúa funcionando (aunque con menor capacidad)

**Escenario C: Fallo temporal de red o aplicación**
- ✅ El health check del ALB detecta el problema
- ✅ El ALB deja de enviar tráfico a la instancia afectada
- ✅ Si el problema se resuelve, la instancia vuelve a ser saludable
- ✅ Si el problema persiste, el ASG reemplaza la instancia

#### 5. **Configuración de Health Check**

**Health Check del ALB:**
- **Protocolo**: HTTP
- **Puerto**: 8080 (configurable mediante `app_port`)
- **Ruta**: `/` (configurable mediante `health_check_path`)
- **Intervalo**: Cada 30 segundos (por defecto)
- **Timeout**: 5 segundos (por defecto)
- **Healthy threshold**: 2 checks exitosos consecutivos
- **Unhealthy threshold**: 2 checks fallidos consecutivos

**Configuración en Terraform:**
```hcl
health_check_type = "ELB"  # Usa health check del ALB
target_group_arns = [module.alb.target_group_arn]  # Conectado al ALB
```

#### 6. **Protecciones Adicionales**

- **Cooldown Period**: 300 segundos (5 minutos) entre acciones de escalado
- **Grace Period**: Tiempo de espera antes de considerar una instancia como no saludable
- **Termination Policies**: El ASG termina instancias de forma inteligente (más antiguas primero, distribuidas entre AZs)

## Configuración de AWS Secrets Manager

### Habilitar Secretos en un Ambiente

Para almacenar secretos usando AWS Secrets Manager, edita `infra/envs/{ambiente}/terraform.tfvars`:

#### Ejemplo: Secreto de Base de Datos
```hcl
# Habilitar creación del secreto de BD
create_db_secret = true
db_username      = "myapp_user"
db_password      = "SuperSecurePassword123!"  # ⚠️ Valor sensible
db_host          = "mydb.example.com"
db_port          = 3306
db_name          = "myapp_db"
db_engine        = "mysql"
```

#### Ejemplo: Secreto de API Keys
```hcl
# Habilitar creación del secreto de API Keys
create_api_keys_secret = true
api_keys = {
  stripe_api_key   = "sk_live_xxxxxxxxxxxxx"  # ⚠️ Valores sensibles
  sendgrid_api_key = "SG.xxxxxxxxxxxxx"
}
```

#### Ejemplo: Secretos Genéricos
```hcl
# Secretos genéricos personalizados
app_secrets = {
  jwt_secret = {
    description   = "JWT signing secret"
    secret_string = jsonencode({
      secret = "my-jwt-secret-key-12345"
    })
  }
}
```

### Acceso a Secretos en las Instancias

Los secretos se descargan automáticamente al iniciar cada instancia en:
- **Ubicación**: `/opt/app/secrets/`
- **Formato**: JSON (archivos `.json`) y variables de entorno (archivos `.env`)
- **Permisos**: Solo lectura para root (600)

**Ejemplo de uso en aplicación**:
```bash
# Cargar variables de entorno de BD
source /opt/app/secrets/db.env

# O leer JSON directamente
cat /opt/app/secrets/genius-dev-database-credentials.json
```

### Documentación Completa

Para más detalles, consulta:
- **Guía completa**: `infra/GUIA_SECRETS_MANAGER.md`
- Incluye ejemplos detallados, troubleshooting, y mejores prácticas

## Recursos y Referencias

- [Documentación de Terraform](https://www.terraform.io/docs)
- [AWS Provider para Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Secrets Manager - Documentación Oficial](https://docs.aws.amazon.com/secretsmanager/)
- [Best Practices de AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Modules Best Practices](https://www.terraform.io/docs/language/modules/develop/index.html)
