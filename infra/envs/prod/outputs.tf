output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID del Application Load Balancer (útil para Route53)"
  value       = module.alb.alb_zone_id
}

output "target_group_arn" {
  description = "ARN del Target Group"
  value       = module.alb.target_group_arn
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group"
  value       = module.autoscaling.autoscaling_group_name
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas"
  value       = module.vpc.public_subnet_ids
}

# Outputs de Secrets Manager
output "db_secret_arn" {
  description = "ARN del secreto de credenciales de base de datos"
  value       = module.secrets_manager.db_secret_arn
}

output "db_secret_name" {
  description = "Nombre del secreto de credenciales de base de datos"
  value       = module.secrets_manager.db_secret_name
}

output "api_keys_secret_arn" {
  description = "ARN del secreto de API Keys"
  value       = module.secrets_manager.api_keys_secret_arn
}

output "all_secret_arns" {
  description = "Lista de todos los ARNs de secretos creados"
  value       = module.secrets_manager.all_secret_arns
}

output "secrets_prefix" {
  description = "Prefijo común para todos los secretos de este proyecto/ambiente"
  value       = module.secrets_manager.secrets_prefix
}
