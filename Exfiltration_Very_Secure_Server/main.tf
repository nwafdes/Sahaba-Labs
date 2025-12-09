provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ==========================================
# 1. Networking (The Trap)
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Gov-Secure-VPC" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Public Subnet (Bastion)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Private Subnet (The Vault) - NO INTERNET ACCESS
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table (No Internet Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================
# 2. The Loophole (S3 Gateway Endpoint)
# ==========================================
# This allows the private server to talk to S3 without internet.
# Vulnerability: It allows access to ANY bucket (including yours).
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  
  # Attach to private route table
  route_table_ids = [aws_route_table.private_rt.id]
}

# ==========================================
# 3. Security Groups
# ==========================================
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from World"
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

resource "aws_security_group" "private_sg" {
  name   = "private-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion ONLY"
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

# ==========================================
# 4. SSH Keys & Instances
# ==========================================
# Generate a key for us to login to Bastion
resource "tls_private_key" "bastion_key" { algorithm = "RSA" }
resource "aws_key_pair" "bastion_kp" {
  key_name   = "bastion-key-${random_id.suffix.hex}"
  public_key = tls_private_key.bastion_key.public_key_openssh
}
resource "local_file" "bastion_pem" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "bastion.pem"
  file_permission = "0400"
}

# Generate a key for the Private Server (Internal Use Only)
resource "tls_private_key" "internal_key" { algorithm = "RSA" }
resource "aws_key_pair" "internal_kp" {
  key_name   = "internal-db-key-${random_id.suffix.hex}"
  public_key = tls_private_key.internal_key.public_key_openssh
}

# The Bastion Host
resource "aws_instance" "bastion" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.bastion_kp.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  # We inject the PRIVATE KEY for the internal server onto the Bastion
  # simulating that a careless admin left it there.
  user_data = <<-EOF
              #!/bin/bash
              echo "${tls_private_key.internal_key.private_key_pem}" > /home/ubuntu/internal.pem
              chown ubuntu:ubuntu /home/ubuntu/internal.pem
              chmod 400 /home/ubuntu/internal.pem
              EOF

  tags = { Name = "Bastion-Jumpbox" }
}

# The Private Server
resource "aws_instance" "private_server" {
  ami           = "ami-068c0051b15cdb816" # Amazon Linux
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  key_name      = aws_key_pair.internal_kp.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  # Create the sensitive data
  user_data = <<-EOF
              #!/bin/bash

              # Create the secret
              echo "CONFIDENTIAL: GOV CONTRACT #99881122" > /home/ubuntu/government_secrets.txt
              chown ec2-user:ec2-user /home/ec2-user/government_secrets.txt
              EOF

  tags = { Name = "Private-Government-DB" }
}

# ==========================================
# 5. Outputs
# ==========================================
output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
output "private_ip" {
  value = aws_instance.private_server.private_ip
}
output "connection_command" {
  value = "ssh -i bastion.pem ubuntu@${aws_instance.bastion.public_ip}"
}