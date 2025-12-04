# Scenario: The Shadow Runner

## The Situation
You have obtained the AWS credentials of a junior DevOps engineer, `devops-junior`. This user is responsible for setting up new CI/CD pipelines for the development team.

They have permissions to create AWS CodeBuild projects and the necessary IAM roles to configure the builds.

## The Constraints
- The `devops-junior` user cannot directly assume other IAM roles.
- The `devops-junior` user cannot directly read the secret located at `prod/app/secret`.

## The Objective
Your goal is to leverage your initial access to establish a persistent foothold in the AWS account and exfiltrate a sensitive flag.

1.  **Establish Persistence:** Create a malicious CodeBuild project that functions as a covert Command and Control (C2) agent, disguised as a self-hosted GitHub Runner connected to an attacker-controlled GitHub repository.
2.  **Verify C2:** Trigger the runner from your GitHub repository to confirm you have remote code execution capabilities within the AWS account's infrastructure.
3.  **Action on Objectives:** Use your C2 channel to retrieve the flag from AWS Secrets Manager.

## Requirements
- An AWS account.
- A GitHub account.
- Terraform (v1.0+) installed.

## Steps to Solve
1.  Deploy the vulnerable infrastructure using the provided Terraform code (`main.tf`).
2.  Configure your local environment with the compromised `devops-junior` AWS credentials.
3.  Create a new IAM Role that your malicious CodeBuild project will assume.
4.  Create a private GitHub repository under your personal account (this will be your "attacker" repository).
5.  Configure the CodeBuild project to act as a GitHub Actions runner, connecting it to your attacker repository.
6.  Create a malicious GitHub Actions workflow file within your attacker repository.
7.  Trigger the workflow to execute commands on the CodeBuild runner.
8.  Use the runner to retrieve the secret flag from AWS Secrets Manager and complete the objective.

---

## Important: Cleanup
After completing the scenario, remember to run `terraform destroy` to remove the resources created by Terraform.

**Note:** The IAM role and CodeBuild project you create manually are **not** tracked in the Terraform state file. You must delete these resources manually from the AWS console to avoid incurring unwanted costs.