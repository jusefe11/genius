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

output "no_healthy_hosts_alarm_arn" {
  description = "ARN de la alarma de sin hosts saludables (aplicacion caida)"
  value       = aws_cloudwatch_metric_alarm.no_healthy_hosts.arn
}

output "high_memory_alarm_arn" {
  description = "ARN de la alarma de RAM alta"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.high_memory[0].arn : null
}

# Outputs de nombres de alarmas para facilitar verificacion
output "no_healthy_hosts_alarm_name" {
  description = "Nombre de la alarma de sin hosts saludables"
  value       = aws_cloudwatch_metric_alarm.no_healthy_hosts.alarm_name
}

output "high_cpu_alarm_name" {
  description = "Nombre de la alarma de CPU alta"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "high_memory_alarm_name" {
  description = "Nombre de la alarma de RAM alta"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.high_memory[0].alarm_name : null
}

output "docker_containers_down_alarm_arn" {
  description = "ARN de la alarma de contenedores Docker caidos"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.docker_containers_down[0].arn : null
}

output "docker_containers_down_alarm_name" {
  description = "Nombre de la alarma de contenedores Docker caidos"
  value       = var.environment == "dev" ? aws_cloudwatch_metric_alarm.docker_containers_down[0].alarm_name : null
}
