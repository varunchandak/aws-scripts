#!/bin/bash

# This script will do the following (in order):
#	- Get a list of instances running inside the autoscaling group
#	- Create an AMI of the particular instance and store AMI ID
#	- fetch the launch configuration name to an autoscaling group (passed as parameter to script)
#	- create a new launch configuration with the updated image
#	- Assign the Launch Configuration to the existing Auto Scaling Group (ASG)
#	- Removal of old Launch Configurations (commented for now)
#
# NOTES:
#	When you change the launch configuration for your Auto Scaling group, 
#		any new instances are launched using the new configuration parameters, 
#		but existing instances are not affected.

if [ "$#" -ne 3 ]; then
	usage
else
	# export AWS PROFILES
	export AWS_PROFILE="$1"
	export AWS_REGION="$2"

	# Enter ASG Name
	export ASG_NAME="$3"

	# Initializing Logic:
	# Setting aws binary location alias with profile parameter
	alias aws=''`which aws`' --region '"$AWS_REGION"' --output text --profile '"$AWS_PROFILE"''
	shopt -s expand_aliases
	
	DATETODAY=$(date +%d%m%Y)
	DATEYESTERDAY=$(date +%d%m%Y --date='yesterday')

	# Get launch configuration name from ASG_NAME
	LC_NAME="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --output text --query 'AutoScalingGroups[].LaunchConfigurationName')"
	NEW_LC_NAME="$(echo $LC_NAME | awk -F- 'sub(FS $NF,x)')"-"$DATETODAY"

	# Get 1 random instance ID from the list of instances running under ASG_NAME
	RANDOM_INST_ID="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --output text --query 'AutoScalingGroups[].Instances[?HealthStatus==`Healthy`].InstanceId' | tr -s '\t' '\n' | shuf -n 1)"

	# Create AMI from the Instance without reboot
	AMI_ID="$(aws ec2 create-image --instance-id $RANDOM_INST_ID --name "$ASG_NAME"-"$DATETODAY" --output text --no-reboot)"

	# Extract existing launch configuration
	aws autoscaling describe-launch-configurations --launch-configuration-names $LC_NAME --output json --query 'LaunchConfigurations[0]' > /tmp/$LC_NAME.json

	# Remove unnecessary and empty entries from the launch configuration JSON and fill up with latest AMI ID
	cat /tmp/$LC_NAME.json | \
		jq 'walk(if type == "object" then with_entries(select(.value != null and .value != "" and .value != [] and .value != {} and .value != [""] )) else . end )' | \
		jq 'del(.CreatedTime, .LaunchConfigurationARN)' | \
		jq ".ImageId = \"$AMI_ID\" | .LaunchConfigurationName = \"$NEW_LC_NAME\"" > /tmp/$NEW_LC_NAME.json

	# Create new launch configuration with new name
	if [ -z "$(jq .UserData /tmp/$LC_NAME.json --raw-output)" ]; then
		aws autoscaling create-launch-configuration \
			--cli-input-json file:///tmp/$NEW_LC_NAME.json
	else
		aws autoscaling create-launch-configuration \
			--cli-input-json file:///tmp/$NEW_LC_NAME.json \
			--user-data file://<(jq .UserData /tmp/$NEW_LC_NAME.json --raw-output | base64 --decode)
	fi

	# Update autoscaling group with new launch configuration
	aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --launch-configuration-name "$NEW_LC_NAME"
	
	# Delete old launch configuration
	#aws autoscaling delete-launch-configuration --launch-configuration-name "$LC_NAME_OLD"
	
	# Resetting aws binary alias
	unalias aws
fi
