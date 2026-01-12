# Data source para obtener la región actual
data "aws_region" "current" {}

# Extraer el nombre del ALB desde el ARN
locals {
  alb_name = split("/", var.alb_arn)[length(split("/", var.alb_arn)) - 1]
  
  # Target Group identifier: formato "targetgroup/name/id" (requerido por CloudWatch)
  # ARN format: arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
  # Extraer la parte despues del ultimo ":" que contiene "targetgroup/name/id"
  target_group_identifier = split(":", var.target_group_arn)[5]
  
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
    TargetGroup  = local.target_group_identifier
    LoadBalancer = local.alb_name
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
    LoadBalancer = local.alb_name
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

# Alarma 4: Sin hosts saludables
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-no-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alerta cuando no hay hosts saludables en el Target Group"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = local.target_group_identifier
    LoadBalancer = local.alb_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-no-healthy-hosts-alarm"
      Type = "cloudwatch-alarm"
    }
  )
}

# Alarma 5: RAM Alta (solo si CloudWatch Agent esta configurado)
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  count = var.environment == "dev" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta cuando el uso de RAM esta por encima del 80%"
  treat_missing_data  = "notEvaluated"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-high-memory-alarm"
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
      # Widget 1: Health Checks - Hosts Saludables vs No Saludables
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "TargetGroup",
              local.target_group_identifier,
              "LoadBalancer",
              local.alb_name,
              {
                stat   = "Average"
                label  = "Hosts Saludables"
                color  = "#2ca02c"
              }
            ],
            [
              "AWS/ApplicationELB",
              "UnHealthyHostCount",
              "TargetGroup",
              local.target_group_identifier,
              "LoadBalancer",
              local.alb_name,
              {
                stat   = "Average"
                label  = "Hosts No Saludables"
                color  = "#d62728"
              }
            ]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Health Checks - Hosts Saludables vs No Saludables"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              label = "Cantidad de Hosts"
            }
          }
          annotations = {
            horizontal = [
              {
                value     = 0
                label     = "Sin hosts no saludables"
                color     = "#2ca02c"
                fill      = "below"
                visible   = true
                yAxis     = "left"
              }
            ]
          }
        }
      },
      # Widget 2: CPU Usage (Gráfico línea) - AutoScalingGroupName como dimensión
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
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
      },
      # Widget 3: Errores HTTP 5xx
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              local.alb_name,
              {
                stat   = "Sum"
                label  = "Errores 5xx"
                color  = "#ff7f0e"
              }
            ]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Errores HTTP 5xx"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              label = "Cantidad"
            }
          }
        }
      },
      # Widget 4: Estado de Alarmas
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "UnHealthyHostCount",
              "TargetGroup",
              local.target_group_identifier,
              "LoadBalancer",
              local.alb_name,
              {
                stat   = "Average"
                label  = "Hosts No Saludables (Alarma: > 0)"
                color  = "#d62728"
                yAxis  = "left"
              }
            ]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Estado de Health Checks - Alarma de Hosts No Saludables"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              label = "Cantidad"
            }
          }
          annotations = {
            horizontal = [
              {
                value     = 0
                label     = "Umbral de Alarma"
                color     = "#ff0000"
                fill      = "above"
                visible   = true
                yAxis     = "left"
              }
            ]
          }
        }
      }
    ]
  })
}
