#!/bin/bash

################################################################################
################################### ELB ONLY ###################################
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
./check-unhealthy-hosts.sh <ELB_NAME> <AWS PROFILE> <AWS_REGION>

Example:
./check-unhealthy-hosts.sh test-elb default ap-south-1
'
}

# Slack Settings ###############################################################
slackChannel(){ # subject message
	SLACK_WEBHOOK_URL="<Slack Webhook URL>"
	SLACK_CHANNEL="#<Slack Channel Name>"
	SLACK_BOTNAME="<Slack Bot Name>"
	PAYLOAD="payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"text\": \"Unhealthy hosts checks (every 5 mins): \`\`\`"$1"\`\`\`\"}"
  	curl --connect-timeout 30 --max-time 60 -s -S -X POST --data-urlencode "${PAYLOAD}" "${SLACK_WEBHOOK_URL}"
}

if [ "$#" -ne 3 ]; then
	usage
else
	LB_NAME="$1"
	if [ ! -z "$(aws elb describe-instance-health --load-balancer-name "$LB_NAME" --output text --query 'InstanceStates[?State==`OutOfService`].InstanceId')" ]; then
		echo "$LB_NAME"
		aws elb describe-instance-health \
			--load-balancer-name "$LB_NAME" \
			--query 'InstanceStates[?State==`OutOfService`].InstanceId' | tr -s '\t' ','
	fi | paste -d, - - | while read LBDETAILS; do slackChannel "LoadBalancer: $(echo $LBDETAILS | cut -d, -f1)\nInstanceIds: $(echo $LBDETAILS | cut -d, -f2-)"; done

fi
