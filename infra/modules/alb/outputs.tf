output "alb_id" {
  description = "ID del Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del Application Load Balancer (útil para Route53)"
  value       = aws_lb.main.zone_id
}

output "target_group_id" {
  description = "ID del Target Group"
  value       = aws_lb_target_group.app.id
}

output "target_group_arn" {
  description = "ARN del Target Group (para asociar con ASG)"
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "Nombre del Target Group"
  value       = aws_lb_target_group.app.name
}

output "http_listener_arn" {
  description = "ARN del listener HTTP"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN del listener HTTPS (si está habilitado)"
  value       = var.enable_https ? aws_lb_listener.https[0].arn : null
}
