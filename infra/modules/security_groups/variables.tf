variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crearán los security groups"
  type        = string
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
  description = "Motor de base de datos (mysql, postgres, mongodb, redis)"
  type        = string
  default     = "mysql"
}

variable "enable_ssh" {
  description = "Habilitar acceso SSH (solo para bastion o IPs específicas)"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs permitidas para acceso SSH"
  type        = list(string)
  default     = []
}

variable "allowed_web_cidrs" {
  description = "CIDRs permitidas para acceso web (HTTP/HTTPS). Por defecto cualquier IP (0.0.0.0/0)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_redis" {
  description = "Habilitar Security Group para Redis"
  type        = bool
  default     = false
}

variable "enable_cache" {
  description = "Habilitar Security Group para cache (ElastiCache)"
  type        = bool
  default     = false
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
