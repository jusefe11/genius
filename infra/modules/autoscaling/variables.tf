variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "ami_id" {
  description = "AMI ID para las instancias"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre de la clave SSH (opcional)"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Lista de IDs de security groups"
  type        = list(string)
}

variable "subnet_ids" {
  description = "Lista de IDs de subredes"
  type        = list(string)
}

variable "target_group_arns" {
  description = "ARNs de los target groups del ALB"
  type        = list(string)
  default     = []
}

variable "min_size" {
  description = "Número mínimo de instancias"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Número máximo de instancias"
  type        = number
  default     = 5
}

variable "desired_capacity" {
  description = "Capacidad deseada de instancias"
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Puerto de la aplicación"
  type        = number
  default     = 8080
}
