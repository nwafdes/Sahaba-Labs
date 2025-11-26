![Arabic man and camel in the desert](https://github.com/nwafdes/Sahaba-Labs/blob/main/Gemini_Generated_Image_mpt2nimpt2nimpt2.png?raw=true)

# Sahaba-Labs

This repository contains a collection of labs created for learning and practicing specific scenarios, primarily focused on cloud and security.

## Disclaimer

**This project is for educational purposes only.** The labs and scenarios provided here are meant for learning and experimentation in a controlled environment. Do not use these configurations in a production environment without thorough review and understanding of the potential risks. You are responsible for any costs or security implications that may arise from using these labs in your own cloud accounts.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **Terraform**: The labs use Terraform to provision infrastructure. You can download and install it from the [official Terraform website](https://www.terraform.io/downloads.html).
2.  **AWS CLI**: The AWS Command Line Interface is required to interact with your AWS account. Follow the instructions to [install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).
3.  **AWS Account and Admin User**: You will need an AWS account. It is strongly recommended to create an IAM user with administrative permissions and configure your AWS CLI to use these credentials. Using the root account is discouraged.

## Available Labs

*   **Vulnerable-ASG**: A scenario demonstrating a vulnerable Auto Scaling Group configuration. See the `Scenario.md` file within the `Vulnerable-ASG` directory for more details.

## How to Use

1.  Clone this repository.
2.  Navigate to the directory of the lab you want to practice (e.g., `cd Vulnerable-ASG`).
3.  Follow the instructions in the `Scenario.md` file for that lab.
4.  Typically, you will need to run `terraform init`, `terraform plan`, and `terraform apply` to set up the infrastructure.
5.  Once you are finished, remember to clean up the resources by running `terraform destroy` to avoid incurring unwanted costs.
