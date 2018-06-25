#!/bin/bash 

usage() {
	echo 'Usage:
./script.sh <IAM_USERNAME> <MFA_CODE> <ACCOUNT_ID>

Requires:
* jq
* aws cli
'
}

if [ "$#" -ne 3 ]; then
	usage
else
	IAM_USERNAME="$1"
	MFA_CODE="$2"
	ACCOUNT_ID="$3"
	aws sts get-session-token \
		--serial-number arn:aws:iam::"$ACCOUNT_ID":mfa/"$IAM_USERNAME" \
		--token-code "$MFA_CODE" \
		--duration-seconds 14400 > /tmp/"$IAM_USERNAME".json
	echo "export AWS_ACCESS_KEY_ID=$(jq '.|.Credentials.AccessKeyId' --raw-output /tmp/"$IAM_USERNAME".json)"
	echo "export AWS_SECRET_ACCESS_KEY=$(jq '.|.Credentials.SecretAccessKey' --raw-output /tmp/"$IAM_USERNAME".json)"
	echo "export AWS_SESSION_TOKEN=$(jq '.|.Credentials.SessionToken' --raw-output /tmp/"$IAM_USERNAME".json)"
	echo "export AWS_DEFAULT_REGION=ap-southeast-1"
	echo "export AWS_DEFAULT_OUTPUT=json"
	
	rm -rfv /tmp/"$IAM_USERNAME".json
fi