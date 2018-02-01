#!/bin/bash

usage () {
	echo -e '
Shell Script to add Slack SNS to Cloudwatch alarms of 90% threshold

Requirements:
-	awless installed and configured - IMPORTANT
-	AWS CLI profile with appropriate permissions

Example: ./SCRIPT.sh <CLIENT_AWS_PROFILE> <AWS_REGION> 

#######################################
DISCLAIMER: Test First, Execute Second.
#######################################
'
}

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:"$PATH"
export AWS_PROFILE="$1"
export AWS_REGION="$2"
alias aws='aws --profile '"$AWS_PROFILE"' --region '"$AWS_REGION"''
shopt -s expand_aliases

if [[ "$#" -ne 2 ]]; then
	usage
else
	slackmetrics() {
		aws cloudwatch describe-alarms \
		--output text \
		--query 'MetricAlarms[?contains(AlarmName, `90%`)].AlarmName' | tr -s '\t' '\n' | grep -i "$1" | while read ALARM_NAME; do
		awless -p "$AWS_PROFILE" -r "$AWS_REGION" -f attach alarm action-arn="$SNS_ARN" name=\'"$ALARM_NAME"\'
	done
	}

	SNS_ARN="$(aws sns list-topics --output text --query 'Topics[?contains(TopicArn,`slack-alerts`)].TopicArn')"

	clear
	echo -e "Choose 1 metric to set slack alerts to:\n"
	echo -e "1. CPUUtilization\n2. DiskUtilization\n3. MemoryUtilization\n4. Quit"
	read OPTION

	while true; do
		case "$OPTION" in
			1)	echo "Setting slack alerts for CPUUtilization of 90% threshold only"
				slackmetrics CPU; break
				;;
			2)	echo "Setting slack alerts for DiskUtilization of 90% threshold only"
				slackmetrics Disk; break
				;;
			3)	echo "Setting slack alerts for MemoryUtilization of 90% threshold only"
				slackmetrics Memory; break
				;;
			4)	break
				;;
			*)	echo "Enter correct option."
				;;
		esac
	done
fi
unalias aws

