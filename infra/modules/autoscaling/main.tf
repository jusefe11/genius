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

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Política administrada de AWS para SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile para asociar el role a las instancias EC2
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.project_name}-${var.environment}-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-profile"
    Environment = var.environment
    Project     = var.project_name
  }
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
    app_port = var.app_port
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-app"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-launch-template"
    Environment = var.environment
    Project     = var.project_name
  }
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
