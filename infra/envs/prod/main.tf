module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
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
  enable_deletion_protection = true # Activado para producción
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
}
