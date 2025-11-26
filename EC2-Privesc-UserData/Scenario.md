# Scenario: EC2 Privilege Escalation via User Data

This scenario demonstrates a common AWS privilege escalation vector where an attacker with limited EC2 permissions can gain root access on another EC2 instance by modifying its user data.

## 🎯 Goal

The objective is to gain access to the contents of the `/root/flag.txt` file on the "Target" EC2 instance, which is otherwise inaccessible.

## 📜 Description

The Terraform code in this directory deploys the following environment:

1.  **A Bastion Host**: An EC2 instance that you have SSH access to. This instance has an IAM role attached.
2.  **A Target Instance**: A "production" EC2 instance that is locked down. You do not have an SSH key for it, and its security group only allows SSH access from the Bastion Host (which is also ineffective without a key).
3.  **A Vulnerable IAM Role**: The IAM role attached to the Bastion Host has the `ec2:ModifyInstanceAttribute` permission. This is the key to the vulnerability.
4.  **The Flag**: The Target Instance runs a script on its first boot (`user_data`) that writes a secret flag to `/root/flag.txt`.

The vulnerability lies in the IAM policy attached to the Bastion Host's role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:ModifyInstanceAttribute"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
}
```

The `ec2:ModifyInstanceAttribute` permission is powerful. It allows an entity to change many attributes of an EC2 instance, including its `userData`. User data scripts are executed by `cloud-init` with root privileges when an instance boots up.

An attacker on the Bastion Host can leverage the attached role to modify the user data of the Target Instance, inserting a malicious script. By then stopping and starting the Target Instance, the new script will execute, allowing the attacker to perform actions as root on that machine.

## 🚀 How to Run

1.  Navigate to this directory (`EC2-Privesc-UserData`).
2.  Run `terraform init`.
3.  Run `terraform apply`. This will create the resources and save an SSH private key named `ctf_key.pem` in the current directory.
4.  Note the outputs, especially the `ssh_command`.
5.  Use the `ssh_command` to connect to the Bastion Host.

## 🕵️‍♀️ Your Mission

Your mission is to use the permissions available to you on the Bastion Host to read the flag from the Target Instance.

1.  From the Bastion Host, configure the AWS CLI to use the credentials provided by the EC2 metadata service.
2.  Create a malicious shell script that will read the flag from `/root/flag.txt` and exfiltrate it. For example, it could write the flag to a world-readable file, or send it to a netcat listener you control.
3.  Use the `aws ec2 modify-instance-attribute` command to replace the user data of the Target Instance with your malicious script. Remember to base64 encode your script.
4.  Stop and start the Target Instance to trigger your new user data script.
5.  Retrieve the flag.

Good luck!
