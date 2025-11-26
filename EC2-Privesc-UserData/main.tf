provider "aws" {
  region = "us-east-1" # You can change this if needed
}

# --- Networking ---
resource "aws_vpc" "ctf_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "CTF-VPC" }
}

resource "aws_subnet" "ctf_subnet" {
  vpc_id                  = aws_vpc.ctf_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "CTF-Subnet" }
}

resource "aws_internet_gateway" "ctf_igw" {
  vpc_id = aws_vpc.ctf_vpc.id
}

resource "aws_route_table" "ctf_rt" {
  vpc_id = aws_vpc.ctf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ctf_igw.id
  }
}

resource "aws_route_table_association" "ctf_rta" {
  subnet_id      = aws_subnet.ctf_subnet.id
  route_table_id = aws_route_table.ctf_rt.id
}

# --- Security Groups ---
resource "aws_security_group" "bastion_sg" {
  name        = "ctf_bastion_sg"
  description = "Allow SSH from world"
  vpc_id      = aws_vpc.ctf_vpc.id

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

resource "aws_security_group" "target_sg" {
  name        = "ctf_target_sg"
  description = "Allow SSH only from Bastion"
  vpc_id      = aws_vpc.ctf_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- IAM Vulnerability Setup ---
# 1. The Role
resource "aws_iam_role" "bastion_role" {
  name = "ctf_bastion_role"

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
}

# 2. The Vulnerable Policy (Privilege Escalation Vector)
resource "aws_iam_policy" "vulnerable_policy" {
  name        = "ctf_vulnerable_policy"
  description = "Overly permissive policy for EC2 management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:ModifyInstanceAttribute"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_vuln" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.vulnerable_policy.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "ctf_bastion_profile"
  role = aws_iam_role.bastion_role.name
}

# --- SSH Keys ---
# Generate a key for the player to access the Bastion
resource "tls_private_key" "player_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "player_key_pair" {
  key_name   = "ctf_player_key"
  public_key = tls_private_key.player_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.player_key.private_key_pem
  filename        = "ctf_key.pem"
  file_permission = "0600"
}

# --- Instances ---
# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# 1. The Attacker/Bastion Instance
resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.ctf_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name             = aws_key_pair.player_key_pair.key_name
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name = "CTF-Bastion-Attacker"
  }
}

# 2. The Target/Production Instance
resource "aws_instance" "target" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.ctf_subnet.id
  vpc_security_group_ids = [aws_security_group.target_sg.id]
  # No SSH key assigned intentionally to simulate "Lost Access" or "Locked Down"

  # Creates the flag on first boot
  user_data = <<-EOF
              #!/bin/bash
              echo "CTF{Us3r_D4t4_Pr1v_Esc_Succ3ss}" > /root/flag.txt
              EOF

  tags = {
    Name = "CTF-Target-Production"
  }
}