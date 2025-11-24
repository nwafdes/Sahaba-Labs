terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. Networking (VPC & Security Groups)
# ==========================================
resource "aws_vpc" "ctf_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "ctf-production-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.ctf_vpc.id
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.ctf_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.ctf_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.ctf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "alb_sg" {
  name   = "alb-security-group"
  vpc_id = aws_vpc.ctf_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_sg" {
  name   = "web-instance-sg"
  vpc_id = aws_vpc.ctf_vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 2. IAM Roles
# ==========================================

# Low Priv (Web Server)
resource "aws_iam_role" "low_priv_role" {
  name = "web-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_instance_profile" "low_priv_profile" {
  name = "web-server-profile"
  role = aws_iam_role.low_priv_role.name
}

# High Priv (Target)
resource "aws_iam_role" "high_priv_role" {
  name = "maintenance-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_instance_profile" "high_priv_profile" {
  name = "maintenance-admin-profile"
  role = aws_iam_role.high_priv_role.name
}

# Target Bucket & Flag
resource "random_id" "suffix" { byte_length = 4 }
resource "aws_s3_bucket" "flag_bucket" {
  bucket        = "ctf-admin-secrets-${random_id.suffix.hex}"
  force_destroy = true
}
resource "aws_s3_object" "flag" {
  bucket  = aws_s3_bucket.flag_bucket.id
  key     = "flag.txt"
  content = "FLAG{LAUNCH_TEMPLATES_ARE_VULNERABLE_TOO}"
}
resource "aws_iam_role_policy" "admin_s3_access" {
  name = "s3-full-access"
  role = aws_iam_role.high_priv_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = ["s3:GetObject", "s3:ListBucket"], Effect = "Allow", Resource = "*" }]
  })
}

# ==========================================
# 3. Infrastructure (ALB + ASG + Launch Template)
# ==========================================

resource "aws_lb" "app_lb" {
  name               = "ctf-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "ctf-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ctf_vpc.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- NEW: Launch Template instead of Launch Configuration ---
resource "aws_launch_template" "clean_template" {
  name = "production-launch-template"
  
  image_id      = "ami-0c7217cdde317cfec" # Ubuntu 22.04 us-east-1
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.low_priv_profile.name
  }

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              echo "<h1>Welcome to the CTF Web Server (Template Version)</h1>" > /var/www/html/index.html
              systemctl start apache2
              systemctl enable apache2
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ctf-web-instance"
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "ctf-web-asg"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  min_size            = 2
  max_size            = 2
  desired_capacity    = 2

  # Using Launch Template here
  launch_template {
    id      = aws_launch_template.clean_template.id
    version = "$Latest"
  }
}

# ==========================================
# 4. The Attacker (User)
# ==========================================
resource "aws_iam_user" "attacker" {
  name = "deploy-bot"
}

resource "aws_iam_access_key" "attacker_key" {
  user = aws_iam_user.attacker.name
}

resource "aws_iam_user_policy" "attacker_policy" {
  name = "template-manager"
  user = aws_iam_user.attacker.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          # Updated: Permissions for Launch Templates (EC2)
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:Describe*",
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:RunInstances" # Often needed implicitly for template validation
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# 5. Outputs
# ==========================================
output "ctf_access_key" { value = aws_iam_access_key.attacker_key.id }
output "ctf_secret_key" { 
  value     = aws_iam_access_key.attacker_key.secret
  sensitive = true 
}
output "load_balancer_dns" { value = aws_lb.app_lb.dns_name }
output "target_bucket" { value = aws_s3_bucket.flag_bucket.id }
output "target_iam_profile" { value = aws_iam_instance_profile.high_priv_profile.name }
output "security_group_id" { value = aws_security_group.instance_sg.id }
output "original_template_id" { value = aws_launch_template.clean_template.id }