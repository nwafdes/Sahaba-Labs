provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. The Victim's "Secret" Source Bucket
# ==========================================
resource "random_id" "id" {
  byte_length = 4
}

resource "aws_s3_bucket" "source_bucket" {
  bucket        = "corp-secret-data-${random_id.id.hex}"
  force_destroy = true
}

# Replication REQUIRES Versioning to be enabled
resource "aws_s3_bucket_versioning" "source_versioning" {
  bucket = aws_s3_bucket.source_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "secret_file" {
  bucket  = aws_s3_bucket.source_bucket.id
  key     = "financials/Q3_report.pdf"
  content = "CONFIDENTIAL DATA: DO NOT LEAK"
}

# ==========================================
# 2. The Vulnerable IAM User (You)
# ==========================================
resource "aws_iam_user" "victim_user" {
  name = "backup-admin"
}

resource "aws_iam_access_key" "victim_key" {
  user = aws_iam_user.victim_user.name
}

resource "aws_iam_user_policy" "backup_policy" {
  name = "s3-replication-manager"
  user = aws_iam_user.victim_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReplicationConfig"
        Effect = "Allow"
        Action = [
          "s3:PutReplicationConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowPassRoleToS3"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.replication_role.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" : "s3.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ==========================================
# 3. The "Legitimate" Replication Role
# ==========================================
# This is the role the S3 service will "assume" to copy the data.
resource "aws_iam_role" "replication_role" {
  name = "s3-replication-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# The role needs permission to read source and write to *any* destination
# (A loose policy often found in backup roles)
resource "aws_iam_role_policy" "replication_perms" {
  name = "s3-copy-permissions"
  role = aws_iam_role.replication_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.source_bucket.arn]
      },
      {
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.source_bucket.arn}/*"]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = "*" # VULNERABILITY: Can write to ANY bucket
      }
    ]
  })
}

# ==========================================
# 4. Outputs
# ==========================================
output "attacker_access_key" {
  value = aws_iam_access_key.victim_key.id
}
output "attacker_secret_key" {
  value     = aws_iam_access_key.victim_key.secret
  sensitive = true
}
output "source_bucket_name" {
  value = aws_s3_bucket.source_bucket.id
}
output "replication_role_arn" {
  value = aws_iam_role.replication_role.arn
}
