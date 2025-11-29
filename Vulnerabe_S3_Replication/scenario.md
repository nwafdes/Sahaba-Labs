# S3 Replication Misconfiguration Scenario

This scenario demonstrates how a misconfigured IAM policy for S3 replication can be exploited to exfiltrate data to an attacker-controlled S3 bucket.

The Terraform script sets up the following "victim" environment:

*   An S3 bucket (`corp-secret-data-*`) containing a secret file.
*   An IAM user (`backup-admin`) with permissions to configure S3 replication.
*   An IAM role (`s3-replication-runner`) that the S3 service assumes to perform replication.

The vulnerability lies in the IAM role policy, which allows replication to any destination bucket (`Resource = "*"`).

## Requirements

To set up this lab, you will need:

*   Two AWS accounts: one for the "victim" and one for the "attacker".
*   Admin access in both accounts.
*   Terraform installed.
*   AWS CLI configured with profiles for both the victim and attacker accounts.

<br>

> [!IMPORTANT]
> <font color="red">When you are finished with the lab and run `terraform destroy`, you will encounter an error: `A replication configuration is present on this bucket, so you cannot change the versioning state. To change the versioning state, first delete the replication configuration.` This is because the replication configuration we create is not tracked in the Terraform state. To resolve this, you must manually delete the replication configuration from the source bucket using the following AWS CLI command:</font>
>
> ```bash
> aws s3api delete-bucket-replication --bucket [SOURCE_BUCKET_NAME] --profile victim
> ```
