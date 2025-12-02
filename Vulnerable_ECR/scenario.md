# 🕵️‍♂️ Scenario: The Publicly Private Repo

## The Story
A startup company, "QuickShip.io," uses Amazon ECR (Elastic Container Registry) to store the Docker images for their proprietary backend logic. A developer needed to grant a contractor temporary access to one of the images. Frustrated with the complexity of IAM roles and cross-account ARNs, the developer took a shortcut. They applied a repository policy that seemed to work, setting the `Principal` to `*` to "just get it done." They assumed this was safe because the repository URI was not public.

What they didn't realize is that they had just made the company's private container image accessible to **any authenticated AWS user**.

## The Vulnerability
The ECR repository `quickship-internal-backend` has a resource-based policy that allows any AWS principal (`Principal: "*"`) to perform critical actions, including:
- `ecr:BatchGetImage`
- `ecr:GetDownloadUrlForLayer`
- `ecr:DescribeImages`
- `ecr:ListImages`

This means that an attacker who discovers the repository URI can pull the image using their **own** AWS credentials, without needing any access to the victim's account.

## The Objective
Your mission is to exploit this misconfiguration to retrieve a flag hidden inside the container image.

1.  **Deploy the infrastructure** in the "victim" AWS account using the provided Terraform code.
2.  **Identify the target repository URI** from the Terraform output.
3.  **Configure your AWS CLI** to use your separate "attacker" AWS account credentials.
4.  **Authenticate** your Docker client to the victim's ECR registry using your attacker credentials.
5.  **Pull the Docker image** from the `quickship-internal-backend` repository.
6.  **Run the container** and find the flag hidden inside.

---

## Prerequisites
To run this lab, you will need the following:

*   **Terraform:** To deploy the vulnerable infrastructure.
*   **AWS CLI:** To interact with AWS services.
*   **Docker:** To pull and run the container image.
*   **Two AWS Accounts:**
    1.  **Victim Account:** An AWS account where you will deploy the vulnerable ECR repository using Terraform.
    2.  **Attacker Account:** A separate AWS account that will be used to pull the image and simulate the attack.

## Deployment
1.  Configure your AWS CLI with the **victim** account credentials.
2.  Navigate to the root directory of this lab.
3.  Run `terraform init` to initialize the Terraform providers.
4.  Run `terraform apply --auto-approve` to deploy the resources.
5.  Note the `target_repo_uri` from the Terraform output. This is the URI of the vulnerable ECR repository.

## Attack Steps
1.  Configure your AWS CLI with the **attacker** account credentials.
2.  Use the AWS CLI to get a login password for the victim's ECR registry.
    ```sh
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <VICTIM_AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
    ```
    *(Replace `<VICTIM_AWS_ACCOUNT_ID>` with the account ID of your victim account)*
3.  Pull the image using the URI from the Terraform output.
    ```sh
    docker pull <TARGET_REPO_URI>:v1
    ```
4.  Run the container to reveal the flag.
    ```sh
    docker run --rm <TARGET_REPO_URI>:v1
    ```

Good luck, and happy hacking!
