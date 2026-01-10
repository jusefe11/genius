variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "genius"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, prod)"
  type        = string
}
