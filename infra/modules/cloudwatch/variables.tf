variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, prod)"
  type        = string
}

variable "alb_arn" {
  description = "ARN del Application Load Balancer"
  type        = string
}

variable "target_group_arn" {
  description = "ARN del Target Group"
  type        = string
}

variable "target_group_name" {
  description = "Nombre del Target Group"
  type        = string
}

variable "asg_name" {
  description = "Nombre del Auto Scaling Group"
  type        = string
}

variable "cpu_threshold" {
  description = "Umbral de CPU para la alarma (porcentaje)"
  type        = number
  default     = 80
}

variable "error_5xx_threshold" {
  description = "Umbral de errores 5xx para la alarma (cantidad)"
  type        = number
  default     = 5
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
