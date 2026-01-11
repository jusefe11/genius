project_name = "genius"
environment  = "dev"

aws_region = "us-east-1"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.20.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

app_port = 8080

# Configuración de Security Groups
db_port   = 3306
db_engine = "mysql"

# SSH: DESHABILITADO - Acceso mediante AWS Systems Manager Session Manager únicamente
# enable_ssh = false  # No usar SSH - acceso solo mediante Session Manager desde consola de AWS
# allowed_ssh_cidrs = []  # No se requiere - acceso mediante SSM Session Manager

# Redis/Cache: habilitar si usas ElastiCache
# enable_redis = true

# Configuración de Application Load Balancer
# Para habilitar HTTPS, descomenta las siguientes líneas y proporciona el certificate_arn:
# enable_https = true
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"  # REQUERIDO si enable_https = true
enable_https = false  # Deshabilitado hasta tener certificado SSL/TLS
health_check_path = "/"

# Configuración de Auto Scaling Group
# ami_id = "ami-xxxxx"  # Dejar vacío para usar la AMI más reciente de Amazon Linux 2
instance_type = "t3.micro"
# key_name no se usa - acceso mediante AWS Systems Manager Session Manager
# Las instancias tienen un IAM Role con política AmazonSSMManagedInstanceCore
# Acceso: Consola de AWS -> EC2 -> Instancias -> Conectar -> Session Manager

# Capacidades del Auto Scaling Group
# Configuración igualada para todos los ambientes
min_size         = 2  # Cambiado de 1 a 2 para igualar con otros ambientes
desired_capacity = 2  # Mantiene 2 instancias deseadas
max_size         = 5  # Mantiene máximo de 5 instancias
# trigger pipeline

# Tags para FinOps (Gestión de Costos)
cost_center = "engineering"
owner       = "platform-team"
team        = "platform-engineering"
managed_by  = "terraform"

# ==============================================================================
# AWS Secrets Manager Configuration
# ==============================================================================
# Para almacenar secretos de forma segura usando AWS Secrets Manager
# Ver: infra/GUIA_SECRETS_MANAGER.md para más detalles

# Secreto de Base de Datos (deshabilitado por defecto)
# create_db_secret = false
# db_username      = "myapp_user"
# db_password      = "SuperSecurePassword123!"  # ⚠️ Valor sensible
# db_host          = "mydb.example.com"
# db_port          = 3306
# db_name          = "myapp_db"
# db_engine        = "mysql"

# Secreto de API Keys (deshabilitado por defecto)
# create_api_keys_secret = false
# api_keys = {
#   stripe_api_key   = "sk_live_xxxxxxxxxxxxx"  # ⚠️ Valores sensibles
#   sendgrid_api_key = "SG.xxxxxxxxxxxxx"
# }

# Secretos Genéricos (opcional)
# app_secrets = {
#   jwt_secret = {
#     description   = "JWT signing secret"
#     secret_string = jsonencode({
#       secret = "my-jwt-secret-key-12345"
#     })
#   }
# }

# Clave KMS personalizada para cifrar secretos (opcional)
# Si no se especifica, usa la clave por defecto de Secrets Manager
# secrets_manager_kms_key_ids = []

