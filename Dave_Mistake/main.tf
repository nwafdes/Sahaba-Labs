provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ==========================================
# 1. The Prize (Secret)
# ==========================================
resource "aws_secretsmanager_secret" "flag" {
  name        = "prod/billing/stripe-keys-${random_id.suffix.hex}"
  description = "Production Stripe API Keys"
}

resource "aws_secretsmanager_secret_version" "flag_val" {
  secret_id     = aws_secretsmanager_secret.flag.id
  secret_string = "{\"api_key\": \"FLAG{NEVER_TRUST_WILDCARD_PRINCIPALS}\"}"
}

# ==========================================
# 2. The Vulnerable Role
# ==========================================
resource "aws_iam_role" "vulnerable_role" {
  name = "cross-account-billing-role-${random_id.suffix.hex}"

  # VULNERABILITY: Principal "*" allows ANY AWS account to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "AWS": "*" 
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Give the role permission to read the secret
resource "aws_iam_role_policy" "role_perms" {
  name = "billing-access"
  role = aws_iam_role.vulnerable_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# 3. The Leak (Public S3 Bucket)
# ==========================================
resource "aws_s3_bucket" "public_assets" {
  bucket        = "dev-deployment-logs-${random_id.suffix.hex}"
  force_destroy = true
}

# Turn off Block Public Access
resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy to allow Public Read
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.public_assets.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.public_assets.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.allow_public]
}

# The Leaked File containing the Role ARN
resource "aws_s3_object" "leak" {
  bucket = aws_s3_bucket.public_assets.id
  key    = "logs/deploy-2023-10-27.log"
  content = <<EOF
[INFO] 2023-10-27 10:00:12 Starting deployment of Billing Service...
[INFO] 2023-10-27 10:00:15 Creating S3 Buckets... Done.
[WARN] 2023-10-27 10:00:18 Cross-Account Trust Policy set to WILDCARD (*) for debug purposes.
[INFO] 2023-10-27 10:00:19 Created Role: ${aws_iam_role.vulnerable_role.arn}
[INFO] 2023-10-27 10:00:20 Deployment Complete.
EOF
}

# ==========================================
# 4. Outputs (For you to start the lab)
# ==========================================
output "leak_bucket_url" {
  value = "https://${aws_s3_bucket.public_assets.bucket}.s3.amazonaws.com/logs/deploy-2023-10-27.log"
  description = "You found this URL in a Google Dork..."
}