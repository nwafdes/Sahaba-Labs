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
# 1. The Vulnerable ECR Repo
# ==========================================
resource "aws_ecr_repository" "secret_repo" {
  name                 = "quickship-internal-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ==========================================
# 2. The Misconfiguration (Resource Policy)
# ==========================================
resource "aws_ecr_repository_policy" "public_policy" {
  repository = aws_ecr_repository.secret_repo.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowOpenPull",
        Effect    = "Allow",
        Principal = "*", # <--- VULNERABILITY: Any AWS Account can access
        Action    = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
      }
    ]
  })
}

# ==========================================
# 3. Create & Push the "Flag" Image
# ==========================================
# We create a dummy Dockerfile with the flag
resource "local_file" "dockerfile" {
  filename = "${path.module}/Dockerfile"
  content  = <<EOF
FROM alpine:latest
# Hide the flag in the filesystem
RUN echo "FLAG{ECR_WILDCARD_POLICIES_ARE_DANGEROUS}" > /etc/company_secrets.txt
CMD ["cat", "/etc/company_secrets.txt"]
EOF
}

# Build and Push using local docker client
resource "null_resource" "push_image" {
  triggers = {
    file_hash = local_file.dockerfile.content
  }
  depends_on = [aws_ecr_repository.secret_repo]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      # 1. Login as the CREATOR (The Victim) to push the initial image
      aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin ${aws_ecr_repository.secret_repo.repository_url}
      
      # 2. Build
      sudo docker build -t ${aws_ecr_repository.secret_repo.repository_url}:v1 -f ${local_file.dockerfile.filename} .
      
      # 3. Push
      sudo docker push ${aws_ecr_repository.secret_repo.repository_url}:v1
    EOT
  }
}

# ==========================================
# 4. Outputs
# ==========================================
output "target_repo_uri" {
  value = aws_ecr_repository.secret_repo.repository_url
  description = "The Victim Repository URI"
}