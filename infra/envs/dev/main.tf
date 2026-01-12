module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

module "security_groups" {
  source = "../../modules/security_groups"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  app_port          = var.app_port
  db_port           = var.db_port
  db_engine         = var.db_engine
  enable_ssh        = var.enable_ssh
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  enable_redis      = var.enable_redis

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

# Data source para obtener la AMI más reciente de Amazon Linux 2 si no se especifica
data "aws_ami" "amazon_linux" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Módulo Application Load Balancer
module "alb" {
  source = "../../modules/alb"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_security_group_id]
  app_port         = var.app_port
  health_check_path = var.health_check_path
  enable_https     = var.enable_https
  certificate_arn  = var.certificate_arn
  enable_deletion_protection = false # Desactivado para dev

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

# Módulo Secrets Manager
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name  = var.project_name
  environment   = var.environment

  # Secreto de Base de Datos
  create_db_secret = var.create_db_secret
  db_username      = var.db_username
  db_password      = var.db_password
  db_host          = var.db_host
  db_port          = var.db_port
  db_name          = var.db_name
  db_engine        = var.db_engine

  # Secreto de API Keys
  create_api_keys_secret = var.create_api_keys_secret
  api_keys               = var.api_keys

  # Secretos genéricos
  app_secrets = var.app_secrets

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

# Módulo Auto Scaling Group
module "autoscaling" {
  source = "../../modules/autoscaling"

  project_name      = var.project_name
  environment       = var.environment
  ami_id            = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type     = var.instance_type
  key_name          = var.key_name != "" ? var.key_name : null
  security_group_ids = [module.security_groups.app_security_group_id]
  subnet_ids        = module.vpc.private_subnet_ids  # ASG en subredes privadas
  target_group_arns = [module.alb.target_group_arn]  # Conectado al ALB
  app_port          = var.app_port
  min_size          = var.min_size
  max_size          = var.max_size
  desired_capacity  = var.desired_capacity

  # Secrets Manager
  secrets_manager_arns         = module.secrets_manager.all_secret_arns
  secrets_manager_kms_key_ids  = var.secrets_manager_kms_key_ids
  secrets_manager_secret_names = concat(
    var.create_db_secret && module.secrets_manager.db_secret_name != null ? [module.secrets_manager.db_secret_name] : [],
    var.create_api_keys_secret && module.secrets_manager.api_keys_secret_name != null ? [module.secrets_manager.api_keys_secret_name] : [],
    [for k, v in module.secrets_manager.app_secrets_names : v]
  )

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

# Módulo CloudWatch (Monitoreo)
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name       = var.project_name
  environment        = var.environment
  alb_arn            = module.alb.alb_arn
  target_group_arn   = module.alb.target_group_arn
  target_group_name  = module.alb.target_group_name
  asg_name           = module.autoscaling.autoscaling_group_name
  cpu_threshold      = 80
  error_5xx_threshold = 5

  # Tags para FinOps
  cost_center = var.cost_center
  owner       = var.owner
  team        = var.team
  managed_by  = var.managed_by
}

# Data source para obtener la región actual (para el dashboard personalizado de dev)
data "aws_region" "current" {}

# Locals para el dashboard personalizado de dev
locals {
  # ALB name: última parte del ARN (ej: app/genius-dev-alb/1234567890abcdef)
  alb_name = split("/", module.alb.alb_arn)[length(split("/", module.alb.alb_arn)) - 1]
  
  # Target Group identifier: formato "targetgroup/name/id" (requerido por CloudWatch)
  # ARN format: arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
  # split(":") da: ["arn", "aws", "elasticloadbalancing", "region", "account", "targetgroup/name/id"]
  # Tomamos el último elemento (índice 5) que contiene "targetgroup/name/id"
  target_group_parts = split(":", module.alb.target_group_arn)
  target_group_identifier = local.target_group_parts[length(local.target_group_parts) - 1]
}

# Dashboard personalizado solo para dev con Health Checks mejorados
resource "aws_cloudwatch_dashboard" "dev_enhanced" {
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
      # Widget 2: CPU Usage
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
              module.autoscaling.autoscaling_group_name
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
      # Widget 4: Estado de Alarmas - Hosts No Saludables
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

  depends_on = [module.cloudwatch]
}
