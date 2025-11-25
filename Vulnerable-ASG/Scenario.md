🕵️‍♂️ Operation: Rolling Thunder
📅 The Background
Global Logistics Corp is a shipping giant moving their legacy infrastructure to the cloud. They are proud of their "self-healing" web infrastructure that uses Auto Scaling Groups to handle traffic spikes.

However, their DevOps practices are... messy. A disgruntled junior developer recently left the company, and in their haste, they accidentally committed a .env file containing AWS Access Keys to a public GitHub repository.

The security team has revoked the user's console access, but they forgot to rotate the API keys for the service accounts the developer was using.

🎯 The Mission
You are a Red Team operator hired to demonstrate the impact of this leak. Your objective is to move from a compromised service account to full administrative control over the production environment and exfiltrate the CEO's private secrets.

🔓 Initial Access
You have obtained the AWS Access Key ID and Secret Access Key for a user named deploy-bot.

User: deploy-bot

Role: CI/CD Service Account

Known Permissions: It is used to update the web cluster configuration (Launch Templates and Auto Scaling).

🏰 The Infrastructure
Intelligence indicates the following architecture:

Web Tier: An Auto Scaling Group (ctf-web-asg) running Ubuntu instances behind an Application Load Balancer.

Security: The current instances are locked down. You do not have the SSH keys to the currently running servers.

The Rumor: There is a high-privilege IAM Role used for "Maintenance" tasks (maintenance-admin-role) that allows S3 Admin access, but it is not currently assigned to the web servers.

🚩 The Objective
Reconnaissance: Use the deploy-bot keys to map out the environment. Find the target "Maintenance" IAM Instance Profile.

Weaponization: You cannot SSH into the current servers. You must trick the Auto Scaling Group into launching a new server that has:

The High-Privilege "Maintenance" Role.

An SSH Key you control.

Execution: Force the infrastructure to "heal" itself by replacing a server with your malicious one.

Exfiltration: SSH into your malicious instance and steal the contents of flag.txt from the hidden Admin S3 bucket.

⚠️ Rules of Engagement
You may not disrupt the service availability (ensure min_size remains satisfied, though a rolling update is acceptable).

You are starting "Blind." You do not know the exact S3 bucket name or the Profile ARN until you enumerate them.

Good luck, Operator.