locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    CostCenter  = var.cost_center
    Owner       = var.owner
    Team        = var.team
    ManagedBy   = var.managed_by
  }
}

# IAM Role para SSM Session Manager
resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}-${var.environment}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ssm-role"
    }
  )
}

# Política administrada de AWS para SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política IAM para permitir leer secretos de AWS Secrets Manager
resource "aws_iam_role_policy" "secrets_manager_read" {
  count = length(var.secrets_manager_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-secrets-manager-read"
  role  = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_manager_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.secrets_manager_kms_key_ids
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Data source para obtener la región actual
data "aws_region" "current" {}

# IAM Instance Profile para asociar el role a las instancias EC2
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.project_name}-${var.environment}-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ssm-profile"
    }
  )
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  # key_name no se incluye - acceso solo mediante SSM Session Manager
  key_name = null

  # IAM Instance Profile para SSM Session Manager
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  # Security groups - las instancias se lanzan en subredes privadas (configurado en ASG)
  vpc_security_group_ids = var.security_group_ids

  # No asignar IP pública - las instancias están en subredes privadas
  # El ASG especifica las subredes privadas, por lo que automáticamente no tendrán IP pública

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_port                = var.app_port
    secrets_manager_secrets = join(" ", var.secrets_manager_secret_names)
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-app"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-launch-template"
    }
  )
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier  = var.subnet_ids
  target_group_arns    = var.target_group_arns
  health_check_type    = "ELB"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "CostCenter"
    value               = var.cost_center
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = var.owner
    propagate_at_launch = true
  }

  tag {
    key                 = "Team"
    value               = var.team
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = var.managed_by
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.environment}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.environment}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}
