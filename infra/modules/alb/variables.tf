variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se creará el ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subredes públicas donde se desplegará el ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs de los security groups para el ALB (debe permitir 80/443 desde Internet)"
  type        = list(string)
}

variable "app_port" {
  description = "Puerto de la aplicación en los targets"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Ruta para el health check del target group"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "Códigos HTTP que indican un health check exitoso"
  type        = string
  default     = "200"
}

variable "enable_https" {
  description = "Habilitar listener HTTPS (requiere certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN del certificado SSL/TLS para HTTPS (requerido si enable_https = true)"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "Política SSL para el listener HTTPS"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "enable_deletion_protection" {
  description = "Habilitar protección contra eliminación del ALB"
  type        = bool
  default     = false
}
