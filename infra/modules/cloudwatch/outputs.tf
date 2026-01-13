output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = var.environment == "dev" ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}

output "dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = var.environment == "dev" ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
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

