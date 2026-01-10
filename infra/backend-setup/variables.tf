variable "aws_region" {
  description = "Región de AWS donde se crearán los recursos del backend"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "genius"
}

variable "state_bucket_name" {
  description = "Nombre del bucket S3 para almacenar el estado de Terraform"
  type        = string
  default     = "genius-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB para bloqueo de estado"
  type        = string
  default     = "terraform-locks"
}