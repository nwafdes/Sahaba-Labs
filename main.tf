terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. The Prize: Secrets Manager Secret
# ==========================================
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "flag_secret" {
  name        = "production/database/credentials-${random_id.suffix.hex}"
  description = "The flag is hidden here"
}

resource "aws_secretsmanager_secret_version" "flag_value" {
  secret_id     = aws_secretsmanager_secret.flag_secret.id
  secret_string = "{\"flag\": \"FLAG{PYTHON_3.12_STILL_HAS_SECRETS}\"}"
}

# ==========================================
# 2. IAM Role for Lambda
# ==========================================
resource "aws_iam_role" "lambda_role" {
  name = "lambda-proxy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "secrets-access"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets" 
        ]
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# 3. The Vulnerable Lambda Function (Python 3.12)
# ==========================================

# Create the Python file locally
resource "local_file" "vulnerable_code" {
  filename = "${path.module}/lambda_function.py"
  content  = <<EOF
import urllib.request
import json
import os

# Python 3.12 compatible handler
def lambda_handler(event, context):
    # Retrieve query parameters safely
    query_params = event.get('queryStringParameters') or {}
    
    target_url = query_params.get('url')

    if not target_url:
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'text/plain'},
            'body': 'Usage: ?url=https://example.com'
        }
    
    try:
        # VULNERABILITY: 
        # urllib.request.urlopen in Python 3.12 still supports file:// protocol 
        # unless an opener is explicitly configured to block it.
        with urllib.request.urlopen(target_url) as response:
            # Decode using utf-8, handling potential binary data issues gracefully
            content = response.read().decode('utf-8', errors='replace')
            
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/plain'},
            'body': content
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'text/plain'},
            'body': f"Error fetching URL: {str(e)}"
        }
EOF
}

# Zip the code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.vulnerable_code.filename
  output_path = "${path.module}/lambda_payload.zip"
}

# The Function
resource "aws_lambda_function" "vulnerable_lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "website-status-checker-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  
  # --- UPDATED RUNTIME HERE ---
  runtime       = "python3.12" 

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  depends_on = [local_file.vulnerable_code]
}

# ==========================================
# 4. Expose via Function URL
# ==========================================
resource "aws_lambda_function_url" "public_url" {
  function_name      = aws_lambda_function.vulnerable_lambda.function_name
  authorization_type = "NONE" 
}

# ==========================================
# 5. Outputs
# ==========================================
output "target_url" {
  value = aws_lambda_function_url.public_url.function_url
  description = "The Entry Point: Vulnerable Lambda URL"
}