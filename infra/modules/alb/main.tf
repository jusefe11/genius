# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false # Público
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # Siempre false para permitir destroy rápido
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  # Timeouts para evitar bloqueos durante destroy
  timeouts {
    create = "10m"
    update = "10m"
    delete = "15m"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
    Project     = var.project_name
    Type        = "application-load-balancer"
  }
}

# Target Group para el puerto de la aplicación
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
  }

  deregistration_delay = 30

  # Dependencia explícita para asegurar orden de destroy
  depends_on = [aws_lb.main]

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Environment = var.environment
    Project     = var.project_name
    Type        = "target-group"
  }
}

# Listener HTTP (puerto 80) - redirige a HTTPS si está habilitado Y tiene certificado, sino al target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = (var.enable_https && var.certificate_arn != "") ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = (var.enable_https && var.certificate_arn != "") ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = (var.enable_https && var.certificate_arn != "") ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.app.arn
        }
      }
    }
  }

  # Dependencia explícita para asegurar orden de destroy
  depends_on = [aws_lb.main, aws_lb_target_group.app]

  tags = {
    Name        = "${var.project_name}-${var.environment}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener HTTPS (puerto 443) - solo si está habilitado y tiene certificado
resource "aws_lb_listener" "https" {
  count = var.enable_https && var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  # Dependencia explícita para asegurar orden de destroy
  depends_on = [aws_lb.main, aws_lb_target_group.app]

  tags = {
    Name        = "${var.project_name}-${var.environment}-https-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}
