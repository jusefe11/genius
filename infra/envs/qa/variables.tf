variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDR blocks para las subredes públicas"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDR blocks para las subredes privadas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad"
  type        = list(string)
}

variable "app_port" {
  description = "Puerto de la aplicación"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Puerto de la base de datos"
  type        = number
  default     = 3306
}

variable "db_engine" {
  description = "Motor de base de datos (mysql, postgres, mongodb)"
  type        = string
  default     = "mysql"
}

variable "enable_ssh" {
  description = "Habilitar acceso SSH"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs permitidas para acceso SSH"
  type        = list(string)
  default     = []
}

variable "enable_redis" {
  description = "Habilitar Security Group para Redis"
  type        = bool
  default     = false
}

# Variables para Application Load Balancer
variable "enable_https" {
  description = "Habilitar HTTPS en el ALB (requiere certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN del certificado SSL/TLS para HTTPS"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Ruta para el health check del target group"
  type        = string
  default     = "/"
}

# Variables para Auto Scaling Group
variable "ami_id" {
  description = "AMI ID para las instancias EC2 (Linux AMI de AWS por defecto)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre de la clave SSH (debe existir en AWS)"
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Número mínimo de instancias en el ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Número máximo de instancias en el ASG"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Capacidad deseada de instancias en el ASG"
  type        = number
  default     = 2
}

# Tags para FinOps
variable "cost_center" {
  description = "Centro de costo para gestión FinOps"
  type        = string
  default     = "engineering"
}

variable "owner" {
  description = "Propietario o equipo responsable del recurso"
  type        = string
  default     = "platform-team"
}

variable "team" {
  description = "Equipo que gestiona el recurso"
  type        = string
  default     = "platform-engineering"
}

variable "managed_by" {
  description = "Herramienta de gestión de infraestructura"
  type        = string
  default     = "terraform"
}

# Variables para AWS Secrets Manager
variable "create_db_secret" {
  description = "Crear secreto para credenciales de base de datos en Secrets Manager"
  type        = bool
  default     = false
  sensitive   = false
}

variable "db_username" {
  description = "Usuario de la base de datos (solo si create_db_secret = true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de la base de datos (solo si create_db_secret = true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_host" {
  description = "Host de la base de datos (solo si create_db_secret = true)"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Nombre de la base de datos (solo si create_db_secret = true)"
  type        = string
  default     = ""
}

variable "create_api_keys_secret" {
  description = "Crear secreto para API Keys en Secrets Manager"
  type        = bool
  default     = false
}

variable "api_keys" {
  description = "Mapa de API Keys (clave-valor). Solo usado si create_api_keys_secret = true"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "app_secrets" {
  description = "Mapa de secretos genéricos de la aplicación"
  type = map(object({
    description   = optional(string)
    secret_string = string
  }))
  default   = {}
  sensitive = true
}

variable "secrets_manager_kms_key_ids" {
  description = "Lista de ARNs de claves KMS usadas para cifrar los secretos (opcional, por defecto usa la clave por defecto de Secrets Manager)"
  type        = list(string)
  default     = []
}
