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

# Security Group para Application Load Balancer (ALB)
# Permite HTTP/HTTPS desde Internet según requerimientos
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  name_prefix = null
  description = "Security group para Application Load Balancer - Permite HTTP/HTTPS desde internet"
  vpc_id      = var.vpc_id

  # HTTP desde internet
  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # HTTPS desde internet
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # SSH opcional (solo si está habilitado y desde IPs específicas)
  dynamic "ingress" {
    for_each = var.enable_ssh && length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH desde IPs permitidas"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # Egress: permite todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Type = "load-balancer"
    }
  )
}

# Alias para compatibilidad con código existente
resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  name_prefix = null
  description = "Security group para servidores web (alias para compatibilidad) - Permite HTTP/HTTPS desde internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  dynamic "ingress" {
    for_each = var.enable_ssh && length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH desde IPs permitidas"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-web-sg"
      Type = "web"
    }
  )
}

# Security Group para servidores de aplicación
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for application servers - Allows traffic only from ALB SG"
  vpc_id      = var.vpc_id

  # Puerto de la aplicación solo desde ALB Security Group (principio de mínimo acceso)
  ingress {
    description     = "Application port from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH opcional (solo si está habilitado y desde IPs específicas o bastion)
  dynamic "ingress" {
    for_each = var.enable_ssh && length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH desde IPs permitidas"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # Permitir comunicación entre instancias de la app (puerto de aplicación)
  ingress {
    description     = "Communication between application instances"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    self            = true
  }

  # Egress: permite todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-app-sg"
      Type = "application"
    }
  )
}

# Security Group para bases de datos
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group para bases de datos - Permite acceso solo desde app SG"
  vpc_id      = var.vpc_id

  # Puerto de base de datos según el motor configurado
  ingress {
    description     = "Database access from app SG"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Permitir comunicación entre instancias de BD (para replicación)
  ingress {
    description = "Communication between DB instances (replication)"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    self        = true
  }

  # Egress: permite salida limitada (solo para replicación y backups)
  egress {
    description     = "Allowed outbound for replication and backups"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    self            = true
  }

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.project_name}-${var.environment}-db-sg"
      Type   = "database"
      Engine = var.db_engine
    }
  )
}

# Security Group para Redis/ElastiCache (opcional)
resource "aws_security_group" "redis" {
  count = var.enable_redis ? 1 : 0

  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group para Redis/ElastiCache - Permite acceso solo desde app SG"
  vpc_id      = var.vpc_id

  # Puerto Redis estándar
  ingress {
    description     = "Redis desde app SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Permitir comunicación entre instancias de Redis
  ingress {
    description = "Communication between Redis instances"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    self        = true
  }

  # Puerto para Redis Cluster (para réplicas)
  ingress {
    description     = "Redis Cluster desde app SG"
    from_port       = 16379
    to_port         = 16379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Salida permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.project_name}-${var.environment}-redis-sg"
      Type   = "cache"
      Engine = "redis"
    }
  )
}

# Security Group para Bastion Host (SSH jump server)
resource "aws_security_group" "bastion" {
  count = var.enable_ssh ? 1 : 0

  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host - Allows SSH from specific IPs"
  vpc_id      = var.vpc_id

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH desde IPs permitidas"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Egress: permite todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion-sg"
      Type = "bastion"
    }
  )
}

