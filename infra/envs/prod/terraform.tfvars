# Configuración para ambiente de producción
project_name = "genius"
environment  = "prod"
aws_region   = "us-east-1"
vpc_cidr     = "10.2.0.0/16"

public_subnet_cidrs = [
  "10.2.1.0/24",
  "10.2.2.0/24"
]

private_subnet_cidrs = [
  "10.2.10.0/24",
  "10.2.20.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

app_port = 8080

# Configuración de Security Groups
db_port   = 3306
db_engine = "mysql"

# SSH: habilitar solo si necesitas acceso remoto (recomendado desde VPN o bastion)
# enable_ssh = true
# allowed_ssh_cidrs = ["203.0.113.0/24"]  # Cambia por tu IP o rango de IPs de la oficina/VPN

# Redis/Cache: habilitar si usas ElastiCache
# enable_redis = true

# Configuración de Application Load Balancer (Producción)
# IMPORTANTE: Habilitar HTTPS en producción
# enable_https = true
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"  # REQUERIDO si enable_https = true
health_check_path = "/health"

# Configuración de Auto Scaling Group (Producción)
# ami_id = "ami-xxxxx"  # Dejar vacío para usar la AMI más reciente de Amazon Linux 2
instance_type = "t3.medium"
# key_name = "my-key-pair"  # Nombre de la clave SSH en AWS (opcional, solo si enable_ssh = true)

# Capacidades del Auto Scaling Group (Producción: valores más altos)
min_size         = 2
desired_capacity = 3
max_size         = 20
