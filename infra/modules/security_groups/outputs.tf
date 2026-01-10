output "alb_security_group_id" {
  description = "ID del Security Group para Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "web_security_group_id" {
  description = "ID del Security Group para servidores web (alias para compatibilidad)"
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "ID del Security Group para servidores de aplicación"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID del Security Group para bases de datos"
  value       = aws_security_group.db.id
}

output "redis_security_group_id" {
  description = "ID del Security Group para Redis/ElastiCache (si está habilitado)"
  value       = var.enable_redis ? aws_security_group.redis[0].id : null
}

output "bastion_security_group_id" {
  description = "ID del Security Group para bastion host (si está habilitado)"
  value       = var.enable_ssh ? aws_security_group.bastion[0].id : null
}


# Outputs con nombres para facilitar referencia
output "alb_sg_id" {
  description = "ID del Security Group del ALB (alias)"
  value       = aws_security_group.alb.id
}

output "web_sg_id" {
  description = "ID del Security Group web (alias para compatibilidad)"
  value       = aws_security_group.web.id
}

output "app_sg_id" {
  description = "ID del Security Group de aplicación (alias)"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID del Security Group de base de datos (alias)"
  value       = aws_security_group.db.id
}
