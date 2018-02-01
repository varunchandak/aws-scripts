# AWS Audit Script

This script will:
- check root credentials
- check root account access/secret key disable
- check MFA for all admin users
- check age for credentials
- check iam password policy (uppercase/lowercase/etc)
- check security questions for root access
- check iam policies attached to roles/users
- check cloudtrail configuration
- check aws config
- check security groups for world wide access disability
- check vpc flow logging
- check cloudwatch custom metrics

## Usage
```
aws-audit.sh <AWSCLI PROFILE> <AWS_REGION>
```

## Example:
```
./aws-audit.sh clientname region - Using clientname AWSCLI profile.
```
or,
```
./aws-audit.sh default region - Using default profile.
```

## Notes:
- the following packages are required for proper working of this script.
	1. awscli configured with profiles.
	2. jq for parsing output.
	3. bc for calculating arithmetic values.
- this script must be run on linux machines with BASH, only. Won't work on MacOSX or windows.

## AWS Services in use:
* IAM
* IAM Root Credentials
* CloudWatch Alarms
* CloudTrail
* EC2
* VPC
* AWS Config
