# Backend local por defecto (sin configuración = backend local)
# Para usar S3, descomenta y configura el siguiente bloque:
#
# terraform {
#   backend "s3" {
#     bucket = "your-terraform-state-bucket"
#     key    = "genius/${var.environment}/terraform.tfstate"
#     region = "us-east-1"
#     encrypt = true
#   }
# }
