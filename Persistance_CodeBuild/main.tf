provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ==========================================
# 1. The Goal (Protected Secret)
# ==========================================
resource "aws_secretsmanager_secret" "flag" {
  name        = "prod/app/secret-${random_id.suffix.hex}"
  description = "The target flag"
}

resource "aws_secretsmanager_secret_version" "flag_val" {
  secret_id     = aws_secretsmanager_secret.flag.id
  secret_string = "{\"flag\": \"FLAG{GITHUB_RUNNER_IS_MY_C2_CHANNEL}\"}"
}

# ==========================================
# 2. The Initial Access (Compromised User)
# ==========================================
resource "aws_iam_user" "compromised_user" {
  name = "devops-junior-${random_id.suffix.hex}"
}

resource "aws_iam_access_key" "keys" {
  user = aws_iam_user.compromised_user.name
}

# ==========================================
# 3. The Vulnerable Permissions
# ==========================================
# This policy allows creating the C2 infrastructure (Role + Project)
# but prevents direct abuse (No direct AssumeRole, No direct Secret access)
resource "aws_iam_user_policy" "permissions" {
  name = "ci-cd-setup-policy"
  user = aws_iam_user.compromised_user.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CanCreateTheAgentIdentity",
        Effect = "Allow",
        Action = [
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
          "iam:PassRole" # Needed to give the role to CodeBuild
        ],
        Resource = "*"
      },
      {
        Sid    = "CanCreateTheAgentBody",
        Effect = "Allow",
        Action = [
          "codebuild:CreateProject",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:ListProjects"
        ],
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# 4. Outputs (Your starting keys)
# ==========================================
output "access_key" {
  value = aws_iam_access_key.keys.id
}

output "secret_key" {
  value     = aws_iam_access_key.keys.secret
  sensitive = true
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}