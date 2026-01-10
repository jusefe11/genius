output "state_bucket_name" {
  description = "Nombre del bucket S3 creado para el estado de Terraform"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB para bloqueo de estado"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config" {
  description = "Configuración del backend para usar en los archivos backend.tf"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = "<environment>/terraform.tfstate" # Reemplazar <environment> con dev/qa/prod
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}