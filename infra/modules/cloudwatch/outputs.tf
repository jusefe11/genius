output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "unhealthy_hosts_alarm_arn" {
  description = "ARN de la alarma de instancias no saludables"
  value       = aws_cloudwatch_metric_alarm.unhealthy_hosts.arn
}

output "http_5xx_errors_alarm_arn" {
  description = "ARN de la alarma de errores 5xx"
  value       = aws_cloudwatch_metric_alarm.http_5xx_errors.arn
}

output "high_cpu_alarm_arn" {
  description = "ARN de la alarma de CPU alta"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}
