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
  default     = false  # Cambiado a false por defecto - requiere certificate_arn explícito
}

variable "certificate_arn" {
  description = "ARN del certificado SSL/TLS para HTTPS (requerido si enable_https = true)"
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
  description = "Tipo de instancia EC2 (Free Tier: t3.micro, t2.micro, t4g.micro)"
  type        = string
  default     = "t3.micro"  # Cambiado a Free Tier elegible
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
  default     = 20
}

variable "desired_capacity" {
  description = "Capacidad deseada de instancias en el ASG"
  type        = number
  default     = 3
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
