output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "high_cpu_alarm_arn" {
  description = "ARN de la alarma de CPU alta"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

# Outputs de nombres de alarmas para facilitar verificacion
output "high_cpu_alarm_name" {
  description = "Nombre de la alarma de CPU alta"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "docker_containers_down_alarm_arn" {
  description = "ARN de la alarma de contenedores Docker caidos"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.docker_containers_down[0].arn : null
}

output "docker_containers_down_alarm_name" {
  description = "Nombre de la alarma de contenedores Docker caidos"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.docker_containers_down[0].alarm_name : null
}
