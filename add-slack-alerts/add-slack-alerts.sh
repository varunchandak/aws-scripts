#!/bin/bash

usage () {
	echo -e '
Shell Script to automate Slack Alert configuration on AWS.

Requirements:
-	Incoming webhook URL, from Slack API Settings, to pass as argument to the shell script
-	AWS CLI permissions
-	AWS CLI profile
-	index.js in `S3_BUCKET_URL` location

Example: ./SCRIPT.sh "https://hooks.slack.com/services/FOO/BAR/a1b2c3d4" S3_BUCKET_URL AWS_PROFILE AWS_REGION

Notes:
* `S3_BUCKET_URL` Example = https://s3.ap-south-1.amazonaws.com/<BUCKET_NAME>
#######################################
DISCLAIMER: Test First, Execute Second.
#######################################
'
}

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
SLACK_WEBHOOK="$1"
S3_BUCKET_URL="$2"
AWS_PROFILE="$3"
AWS_REGION="$4"
alias aws='aws --profile '"$AWS_PROFILE"' --region '"$AWS_REGION"''
shopt -s expand_aliases

if [[ "$#" -ne 4 ]]; then
	usage
else

	ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"

	# slack role
	echo '{
	  "Version": "2012-10-17",
	  "Statement": [
	    {
	      "Effect": "Allow",
	      "Principal": {
	        "Service": "lambda.amazonaws.com"
	      },
	      "Action": "sts:AssumeRole"
	    }
	  ]
	}' > slack-alerts-assume-role-policy.json

	aws iam create-role \
		--role-name slack-alerts \
		--assume-role-policy-document file://slack-alerts-assume-role-policy.json \
		--description slack-alerts
	
	# slack role policy

	echo '{
	  "Version": "2012-10-17",
	  "Statement": [
	    {
	      "Effect": "Allow",
	      "Action": "logs:CreateLogGroup",
	      "Resource": "arn:aws:logs:'"$AWS_REGION"':'"$ACCOUNT_ID"':*"
	    },
	    {
	      "Effect": "Allow",
	      "Action": [
	        "logs:CreateLogStream",
	        "logs:PutLogEvents"
	      ],
	      "Resource": [
	        "arn:aws:logs:'"$AWS_REGION"':'"$ACCOUNT_ID"':log-group:/aws/lambda/slack-alerts:*"
	      ]
	    }
	  ]
	}' > slack-alerts-role-policy.json

	# upload policy to IAM
	aws iam create-policy \
		--policy-name slack-alerts \
		--policy-document file://slack-alerts-role-policy.json \
		--description slack-alerts

	# attach policy to role
	aws iam attach-role-policy \
		--role-name slack-alerts \
		--policy-arn arn:aws:iam::"$ACCOUNT_ID":policy/slack-alerts

	# create lambda function
	wget "$S3_BUCKET_URL"/index.js -O index.js

	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		sed -i 's,ENTER_WEBHOOK_HERE,'"$SLACK_WEBHOOK"',g' index.js
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i .bak 's,ENTER_WEBHOOK_HERE,'"$SLACK_WEBHOOK"',g' index.js
	fi
	
	zip -r index.js.zip index.js

	sleep 5
	FUNCTION_ARN="$(aws lambda create-function \
		--function-name slack-alerts \
		--runtime nodejs4.3 \
		--role arn:aws:iam::$ACCOUNT_ID:role/slack-alerts \
		--handler index.handler \
		--description slack-alerts \
		--timeout 10 \
		--memory-size 128 \
		--publish \
		--zip-file fileb://index.js.zip \
		--output text \
		--query FunctionArn)"
	sleep 5

	# create topic and subscription
	TOPIC_ARN="$(aws sns create-topic --name slack-alerts --query TopicArn --output text)"

	aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol lambda --notification-endpoint "$FUNCTION_ARN"

	# remove temp files
	rm -fv slack-alerts-assume-role-policy.json index.js.zip slack-alerts-role-policy.json index.js index.js.bak
fi
