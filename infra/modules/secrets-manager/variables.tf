variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, prod)"
  type        = string
}

# Secreto de Base de Datos
variable "create_db_secret" {
  description = "Crear secreto para credenciales de base de datos"
  type        = bool
  default     = true
}

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_host" {
  description = "Host de la base de datos"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Puerto de la base de datos"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = ""
}

variable "db_engine" {
  description = "Motor de base de datos (mysql, postgres, mongodb, etc.)"
  type        = string
  default     = "mysql"
}

# Secreto de API Keys
variable "create_api_keys_secret" {
  description = "Crear secreto para API Keys"
  type        = bool
  default     = false
}

variable "api_keys" {
  description = "Mapa de API Keys (clave-valor)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Secretos genéricos
variable "app_secrets" {
  description = "Mapa de secretos genéricos de la aplicación"
  type = map(object({
    description   = optional(string)
    secret_string = string
  }))
  default = {}
  sensitive = true
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
