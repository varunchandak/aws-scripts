#!/bin/bash

USERNAME="$1"
AWS_PROFILE="$2"
AWS_REGION="$3"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/snap/bin:"$PATH"
alias aws='aws --profile '"$AWS_PROFILE"' --region '"$AWS_REGION"''
shopt -s expand_aliases

usage() {
	echo 'This script will remove the IAM user and its related entities.
	
	Usage: ./script.sh <USERNAME> <AWS_PROFILE> <AWS_REGION>
	'
}

if [ "$#" -ne 3 ]; then
	usage
else
	USERMFADEVICE="$(aws iam list-mfa-devices --user-name $USERNAME --output text --query MFADevices[].SerialNumber)"
	
	awless -p "$AWS_PROFILE" -r "$AWS_REGION" -f delete loginprofile username="$USERNAME"
	if [[ ! -z "$IAMGROUPPOLICIES" ]]; then
		aws iam list-groups-for-user --user-name $USERNAME --query 'Groups[].GroupName' | tr -s '\t' '\n' | while read IAMGROUPPOLICIES; do
			awless -p "$AWS_PROFILE" -r "$AWS_REGION" -f detach user name="$USERNAME" group="$IAMGROUPPOLICIES"
		done
	fi
	if [[ ! -z "$IAMUSERPOLICIES" ]]; then
		aws iam list-attached-user-policies --user-name $USERNAME --output text --query AttachedPolicies[].PolicyArn | tr -s '\t' '\n' | while read IAMUSERPOLICIES; do
			aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$IAMUSERPOLICIES"
		done
	fi
	if [[ ! -z "$IAMCUSTOMPOLICIES" ]]; then
		aws iam list-user-policies --user-name $USERNAME --output text --query PolicyNames | tr -s '\t' '\n' | while read IAMCUSTOMPOLICIES; do
			aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$IAMCUSTOMPOLICIES"
		done
	fi
	if [[ ! -z "$USERMFADEVICE" ]]; then
		aws iam deactivate-mfa-device --user-name "$USERNAME" --serial-number "$USERMFADEVICE"
		aws iam delete-virtual-mfa-device --serial-number "$USERMFADEVICE"
	fi
	aws iam list-access-keys --user-name "$USERNAME" --output text --query 'AccessKeyMetadata[].AccessKeyId' | while read USERKEYS; do
		awless -p "$AWS_PROFILE" -r "$AWS_REGION" -f delete accesskey id="$USERKEYS" user="$USERNAME"
	done
	awless -p "$AWS_PROFILE" -r "$AWS_REGION" -f delete user name="$USERNAME"
fi
