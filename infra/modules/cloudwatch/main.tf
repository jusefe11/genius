# Data source para obtener la región actual
data "aws_region" "current" {}

# Extraer el nombre del ALB desde el ARN
locals {
  alb_name = split("/", var.alb_arn)[length(split("/", var.alb_arn)) - 1]
  
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    CostCenter  = var.cost_center
    Owner       = var.owner
    Team        = var.team
    ManagedBy   = var.managed_by
  }
}

# ==========================================
# ALARMAS
# ==========================================

# Alarma 1: Instancias no saludables
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alerta cuando hay instancias no saludables en el Target Group"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn
    LoadBalancer = var.alb_arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-unhealthy-hosts-alarm"
      Type = "cloudwatch-alarm"
    }
  )
}

# Alarma 2: Errores 5xx
resource "aws_cloudwatch_metric_alarm" "http_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-http-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "Alerta cuando hay errores 5xx del servidor"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-http-5xx-errors-alarm"
      Type = "cloudwatch-alarm"
    }
  )
}

# Alarma 3: CPU Alta
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "Alerta cuando el CPU está por encima del umbral"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-high-cpu-alarm"
      Type = "cloudwatch-alarm"
    }
  )
}

# ==========================================
# DASHBOARD
# ==========================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-application-status"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: CPU Usage (Gráfico línea) - AutoScalingGroupName como dimensión
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "AutoScalingGroupName",
              var.asg_name
            ]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "CPU Usage (%)"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
              label = "Percent"
            }
          }
        }
      }
    ]
  })
}
