#!/bin/bash

usage() {
	echo 'Set AWS access key, secret key and session token from STS (default 1 hour duration)
Usage:
./script.sh <AWS_PROFILE_NAME> <AWS_REGION>
'
}

if [ "$#" -ne 2 ]; then
	usage
else
	export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
	ACCOUNT_ID="$(aws --profile "$1" sts get-caller-identity --query 'Account' --output text)"
	CREDS_JSON="$(aws --profile "$1" sts assume-role --role-arn "arn:aws:iam::$ACCOUNT_ID:role/<ROLE_NAME>" --role-session-name "sts-creds-$(date +%s)" --output json)"

	echo
	echo "### PROFILE $1 ###"
	echo
	echo 'export AWS_DEFAULT_REGION='"$2"
	echo 'export AWS_ACCESS_KEY_ID='$(echo "$CREDS_JSON" | jq '.Credentials | .AccessKeyId')
	echo 'export AWS_SECRET_ACCESS_KEY='$(echo "$CREDS_JSON" | jq '.Credentials | .SecretAccessKey')
	echo 'export AWS_SESSION_TOKEN='$(echo "$CREDS_JSON" | jq '.Credentials | .SessionToken')
	echo 'export AWS_DEFAULT_OUTPUT=text'
	echo
fi
