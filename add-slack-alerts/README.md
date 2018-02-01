# Shell Script to automate Slack Alert configuration on AWS.

## Requirements:
-	Incoming webhook URL, from Slack API Settings, to pass as argument to the shell script
-	AWS CLI permissions
-	AWS CLI profile
-       index.js in `S3_BUCKET_URL` location

## Example:
```
./SCRIPT.sh "https://hooks.slack.com/services/FOO/BAR/a1b2c3d4" S3_BUCKET_URL AWS_PROFILE AWS_REGION
```

## Usage:
1. Create a webhook for slack from [HERE](https://api.slack.com/incoming-webhooks)
2. Take note of the webhook URL as it is required in the script.
3. When you run the script, it will:
	- Download the NodeJS script from the bucket specified.
	- Edit the script with the webhook URL.
	- zip the script to be uploaded to AWS Lambda.
	- Create the Lambda Function with the zip.

## Notes:
- You have to add Lambda Trigger manually. For example, SNS trigger for lambda.
- The script should work in single run. If not, run it again as it is safe to do.
- `S3_BUCKET_URL` Example = https://s3.ap-south-1.amazonaws.com/<BUCKET_NAME>

## DISCLAIMER
Test First, Execute Second.

P.S.: `index.js` code credit to [Akshay Apte](https://github.com/akshayapte)
