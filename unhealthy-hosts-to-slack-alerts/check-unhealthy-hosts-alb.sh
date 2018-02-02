#!/bin/bash

################################################################################
################################### ALB ONLY ###################################
################################################################################
# This script will check the count (and instance ids) unhealthy hosts of particular load balancer.
# If there are no instances which are OutOfService, no notification will be sent.
# If there are > 2 instances which are OutOfService, notification will be sent to the slack channel.
################################################################################

# Set AWS Alias
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
alias aws=''`which aws`' --profile $2 --output text --region $3'
shopt -s expand_aliases

usage() {
	echo '################################################################################
# This script will check the instance ids for unhealthy hosts of particular load balancer.
# If the instances which are not OutOfService/unhealthy, no notification will be sent.
# If the instances which are OutOfService/unhealthy, notification will be sent to the slack channel.
# Recommended to set cron for every 5/10 minutes and check for instances which are repeating.
################################################################################

Prerequisites:
* Slack Channel
* Slack Webhook URL
* AWS Role on EC2 (or credentials in profile)

Usage:
./check-unhealthy-hosts-alb.sh <TARGET_GROUP_ARN> <AWS PROFILE> <AWS_REGION>

Example:
./check-unhealthy-hosts-alb.sh arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/test-targetgroup/abcd1234 default ap-south-1
'
}

# Slack Settings ###############################################################
slackChannel(){ # subject message
	SLACK_WEBHOOK_URL="<Slack Webhook URL>"
	SLACK_CHANNEL="#<Slack Channel Name>"
	SLACK_BOTNAME="<Slack Bot Name>"
	PAYLOAD="payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"text\": \"Unhealthy Target Groups (every 5 mins): \`\`\`"$1"\`\`\`\"}"
  	curl --connect-timeout 30 --max-time 60 -s -S -X POST --data-urlencode "${PAYLOAD}" "${SLACK_WEBHOOK_URL}"
}

if [ "$#" -ne 3 ]; then
	usage
else
	TG_ARN="$1"
	if [ ! -z "$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id')" ]; then
		echo "$TG_ARN" | cut -d/ -f2
		aws elbv2 describe-target-health \
			--target-group-arn "$TG_ARN" \
			--query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id' | tr -s '\t' ','
	fi | paste -d, - - | while read TGDETAILS; do
			slackChannel "Target Group: $(echo $TGDETAILS | cut -d, -f1)\nInstanceIds: $(echo $TGDETAILS | cut -d, -f2-)"
		done

fi