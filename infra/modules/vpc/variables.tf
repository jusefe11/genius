variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDR blocks para las subredes públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDR blocks para las subredes privadas"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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
