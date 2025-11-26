# Scenario: Vulnerable Lambda Function (SSRF via file://)

This scenario demonstrates a Server-Side Request Forgery (SSRF) vulnerability in a Python 3.12 AWS Lambda function that allows an attacker to read local files from the Lambda execution environment.

## 🎯 Goal

The objective is to exploit the SSRF vulnerability to retrieve a secret flag stored in AWS Secrets Manager. The Lambda function has been granted permissions to access this secret.

## 📜 Description

The Terraform code in this directory deploys the following resources:

1.  **An AWS Secrets Manager Secret**: This secret contains the flag you need to capture.
2.  **An IAM Role for Lambda**: This role grants the Lambda function permission to read from Secrets Manager.
3.  **A Vulnerable Lambda Function**: A Python 3.12 Lambda function that takes a `url` as a query parameter and fetches its content.
4.  **A Lambda Function URL**: This exposes the Lambda function to the public internet without authentication.

The vulnerability lies in the Python code of the Lambda function:

```python
import urllib.request
# ...
def lambda_handler(event, context):
    # ...
    target_url = query_params.get('url')
    # ...
    try:
        # VULNERABILITY: 
        # urllib.request.urlopen in Python 3.12 still supports file:// protocol 
        # unless an opener is explicitly configured to block it.
        with urllib.request.urlopen(target_url) as response:
            content = response.read().decode('utf-8', errors='replace')
    # ...
```

The `urllib.request.urlopen` function in Python 3.12 (and older versions) can handle various URL schemes, including `file://`. The code does not validate the input `url` to restrict it to `http://` or `https://` schemes. This allows an attacker to pass a `file://` URL and read files from the local filesystem of the Lambda container.

## 🚀 How to Run

1.  Navigate to this directory (`Vulnerable-Lambda`).
2.  Run `terraform init`.
3.  Run `terraform apply`. Note the `target_url` output.
4.  Use the `target_url` to interact with the vulnerable Lambda function.

## 🕵️‍♀️ Your Mission

Your mission is to craft a request to the Lambda function that exploits the `file://` wrapper to read environment variables or files within the Lambda execution environment. The goal is to find the AWS credentials (access key, secret key, and session token) that the Lambda function uses.

Once you have the credentials, configure your AWS CLI to use them and retrieve the secret from AWS Secrets Manager.

**Hint**: The Lambda execution environment sets several environment variables, including AWS credentials. You can often find information about the running process and its environment in the `/proc` filesystem on Linux-based systems. For example, `/proc/self/environ`.

Good luck!
