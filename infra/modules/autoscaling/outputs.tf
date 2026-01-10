output "launch_template_id" {
  description = "ID del Launch Template"
  value       = aws_launch_template.app.id
}

output "launch_template_arn" {
  description = "ARN del Launch Template"
  value       = aws_launch_template.app.arn
}

output "launch_template_latest_version" {
  description = "Última versión del Launch Template"
  value       = aws_launch_template.app.latest_version
}

output "autoscaling_group_id" {
  description = "ID del Auto Scaling Group"
  value       = aws_autoscaling_group.app.id
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "autoscaling_group_arn" {
  description = "ARN del Auto Scaling Group"
  value       = aws_autoscaling_group.app.arn
}

output "scale_up_policy_arn" {
  description = "ARN de la política de escalado hacia arriba"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN de la política de escalado hacia abajo"
  value       = aws_autoscaling_policy.scale_down.arn
}
