# Data source para obtener la región actual
data "aws_region" "current" {}

# Extraer el nombre del ALB desde el ARN
locals {
  alb_name = split("/", var.alb_arn)[length(split("/", var.alb_arn)) - 1]
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

  tags = {
    Name        = "${var.project_name}-${var.environment}-unhealthy-hosts-alarm"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cloudwatch-alarm"
  }
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

  tags = {
    Name        = "${var.project_name}-${var.environment}-http-5xx-errors-alarm"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cloudwatch-alarm"
  }
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

  tags = {
    Name        = "${var.project_name}-${var.environment}-high-cpu-alarm"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cloudwatch-alarm"
  }
}

# ==========================================
# DASHBOARD
# ==========================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-application-status"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: Healthy Hosts (Número)
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              {
                "TargetGroup"  = var.target_group_arn
                "LoadBalancer" = var.alb_arn
              }
            ]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Healthy Hosts"
          view   = "singleValue"
        }
      },
      # Widget 2: Request Count (Gráfico línea)
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 9
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              {
                "LoadBalancer" = var.alb_arn
              }
            ]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Request Count"
          view   = "timeSeries"
        }
      },
      # Widget 3: Response Time (Gráfico línea)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 9
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              {
                "LoadBalancer" = var.alb_arn
              }
            ]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Response Time (seconds)"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Seconds"
            }
          }
        }
      },
      # Widget 4: CPU Usage (Gráfico línea)
      {
        type   = "metric"
        x      = 9
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              {
                "AutoScalingGroupName" = var.asg_name
              }
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
