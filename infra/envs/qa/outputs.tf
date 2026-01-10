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
