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

# Alarma 1: CPU Alta
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "Alerta cuando el CPU está por encima del umbral durante 1 minuto"
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

# Alarma 2: Contenedores Docker caidos (solo para dev)
# Esta alarma se activa cuando el numero total de contenedores corriendo en el ASG es menor al esperado
# El threshold se calcula como: expected_containers_per_instance * min_instances
resource "aws_cloudwatch_metric_alarm" "docker_containers_down" {
  count = var.environment == "dev" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-docker-containers-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningContainers"
  namespace           = "Docker/Containers"
  period              = 60
  statistic           = "Sum"
  threshold           = var.expected_docker_containers
  alarm_description   = "Alerta cuando el numero total de contenedores Docker corriendo en el ASG es menor al esperado. La metrica muestra cuantos contenedores estan arriba en total."
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-docker-containers-down-alarm"
      Type = "cloudwatch-alarm"
    }
  )
}

# ==========================================
# DASHBOARD
# ==========================================

# Dashboard simplificado: solo CPU y Docker (solo para dev)
resource "aws_cloudwatch_dashboard" "main" {
  count = var.environment == "dev" ? 1 : 0
  
  dashboard_name = "${var.project_name}-${var.environment}-application-status"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: CPU Usage
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 8

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "AutoScalingGroupName",
              var.asg_name,
              {
                stat   = "Average"
                label  = "CPU Usage"
                color  = "#1f77b4"
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
          annotations = {
            horizontal = [
              {
                value     = 80
                label     = "Umbral de Alarma (80%)"
                color     = "#ff7f0e"
                fill      = "above"
                visible   = true
                yAxis     = "left"
              }
            ]
          }
        }
      },
      # Widget 2: Docker Containers
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 8

        properties = {
          metrics = [
            [
              "Docker/Containers",
              "RunningContainers",
              "AutoScalingGroupName",
              var.asg_name,
              {
                stat   = "Sum"
                label  = "Contenedores Docker Corriendo"
                color  = "#2ca02c"
              }
            ]
          ]
          period = 60
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Docker Containers - Contenedores Corriendo"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              label = "Cantidad de Contenedores"
            }
          }
          annotations = {
            horizontal = [
              {
                value     = var.expected_docker_containers
                label     = "Contenedores Esperados"
                color     = "#ff7f0e"
                fill      = "below"
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
