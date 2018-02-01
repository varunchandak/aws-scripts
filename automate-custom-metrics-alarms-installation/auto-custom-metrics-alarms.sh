#!/bin/bash

# Setting cloudwatch alerts using alarms
# THIS SCRIPT IS INTERACTIVE FOR YOUR OWN SAKE
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:"$PATH"

clear
read -r -e -p "Enter AWS_PROFILE name: " -i "" AWS_PROFILE
read -r -e -p "Enter AWS_REGION name: " -i "" AWS_REGION
read -r -e -p "Enter CLIENT_NAME name: " -i "" CLIENT_NAME
echo "Setting alias"
alias aws='aws --profile ''"$AWS_PROFILE"'' --region '"$AWS_REGION"' --output text'
alias awless='awless -r '"$AWS_REGION"' -p '"$AWS_PROFILE"''
shopt -s expand_aliases

#ACCOUNT ID
ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"
# Set SNS ARN for alerts. Multiple ARN are CSV delimited under single double quotes
awless list topics
read -r -e -p "Enter SNS ARN (Comma separated; no spaces): " -i "" SNS_ARN

# Set instance ID
read -r -e -p "Enter Instance ID: " -i "" INST_ID
echo "Checking custom metrics associated with $INST_ID"
if [ -z "$(aws ec2 describe-instances --instance-id $INST_ID --output text --query 'Reservations[*].Instances[*].Platform')" ]; then
	echo "Instance Platform is Linux"
	INST_PLATFORM="Linux"
else
	echo "Instance Platform is Windows"
	INST_PLATFORM="Windows"
fi
echo "Checking for available Custom Metrics"
#setAlarms function
setMemoryAlarms() {
	# Main logic
	aws cloudwatch list-metrics --output text --query 'Metrics[?Namespace==`'"$2"'`].Dimensions[].Value' | tr -s '\t' '\n' | grep -e "$INST_ID" | while read -r INST_ID; do
		IFS=,
		awless list instances --columns id,name --no-headers --format csv | grep "$INST_ID" | while read -r INST_ID INST_NAME; do
			for PERCENTAGE in 90; do
				ALARM_DESCRIPTION="$CLIENT_NAME $INST_NAME $INST_ID $3 > $PERCENTAGE%"
				awless create alarm -f alarm-actions="$1" namespace="$2" metric="$3" \
				dimensions=InstanceId:"$INST_ID" \
				evaluation-periods=1 \
				operator=GreaterThanOrEqualToThreshold \
				period=300 \
				statistic-function=Average \
				threshold="$PERCENTAGE" \
				name=\'"$ALARM_DESCRIPTION"\' \
				description=\'"$ALARM_DESCRIPTION"\' \
				unit=Percent
			done
		done
	done
}

setDiskAlarmsWindows() {
	# Main logic #setDiskAlarms "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
	aws cloudwatch list-metrics --output text --query 'Metrics[?Namespace==`'"$2"'`].Dimensions' | tr -s '\t' ' ' | sed 's/ /:/g' | paste -d, - - | grep "$INST_ID" | while read -r DISK_DIMENSIONS; do
		DRIVE_ARR=($(echo $DISK_DIMENSIONS | cut -d, -f2 | cut -d: -f2))
		INST_NAME="$(awless list instances --columns id,name --no-headers --format csv | grep "$INST_ID" | awk -F, '{print $NF}')"
		for DRIVE_ID in "${DRIVE_ARR[*]}"; do
			for PERCENTAGE in 90; do
				ALARM_DESCRIPTION="$CLIENT_NAME $INST_NAME $INST_ID $DRIVE_ID: $3 > $PERCENTAGE%"
				awless create alarm -f alarm-actions="$1" namespace="$2" metric="$3" \
					dimensions="$DISK_DIMENSIONS" \
					evaluation-periods=1 \
					operator=GreaterThanOrEqualToThreshold \
					period=300 \
					statistic-function=Average \
					threshold="$PERCENTAGE" \
					name=\'"$ALARM_DESCRIPTION"\' \
					description=\'"$ALARM_DESCRIPTION"\' \
					unit=Percent
			done
		done
	done
}

setDiskAlarmsLinux() {
	# Main logic #setDiskAlarms "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
	aws cloudwatch list-metrics --output text --query 'Metrics[?Namespace==`'"$2"'`].Dimensions' | tr -s '\t' ':' | paste -d, - - - | grep "$INST_ID" | while read -r DISK_DIMENSIONS; do
		DRIVE_ID="$(echo $DISK_DIMENSIONS | awk -F: '{print $NF}')"
		INST_NAME="$(awless list instances --columns id,name --no-headers --format csv | grep "$INST_ID" | awk -F, '{print $NF}')"
		for PERCENTAGE in 90; do
			ALARM_DESCRIPTION="$CLIENT_NAME $INST_NAME $INST_ID $DRIVE_ID $3 > $PERCENTAGE%"
			awless create alarm -f alarm-actions="$1" namespace="$2" metric="$3" \
			dimensions="$DISK_DIMENSIONS" \
			evaluation-periods=1 \
			operator=GreaterThanOrEqualToThreshold \
			period=300 \
			statistic-function=Average \
			threshold="$PERCENTAGE" \
			name=\'"$ALARM_DESCRIPTION"\' \
			description=\'"$ALARM_DESCRIPTION"\' \
			unit=Percent
		done
	done
}
if [ "$INST_PLATFORM" == "Windows" ]; then
	for NAMESPACE_ID in "$INST_PLATFORM"/Disk "$INST_PLATFORM"/Memory; do
		export METRIC_NAME="$(echo "$NAMESPACE_ID" | cut -d/ -f2)"
		if aws cloudwatch list-metrics --output text --query 'Metrics[?Namespace==`'"$NAMESPACE_ID"'`].Dimensions[].Value' | tr -s '\t' '\n' | grep -q "$INST_ID"; then
			echo "Custom Metrics present for $NAMESPACE_ID; Setting Alerts"
			if [ "$METRIC_NAME" == "Disk" ]; then
				setDiskAlarmsWindows "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
			elif [ "$METRIC_NAME" == "Memory" ]; then
				setMemoryAlarms "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
			fi
		else
			echo "Custom Metrics for $METRIC_NAME are not set on $INST_ID; Do it ASAP."
		fi
	done
elif [[ "$INST_PLATFORM" == "Linux" ]]; then
	for NAMESPACE_ID in "$INST_PLATFORM"/Disk "$INST_PLATFORM"/Memory; do
		export METRIC_NAME="$(echo "$NAMESPACE_ID" | cut -d/ -f2)"
		if aws cloudwatch list-metrics --output text --query 'Metrics[?Namespace==`'"$NAMESPACE_ID"'`].Dimensions[].Value' | tr -s '\t' '\n' | grep -q "$INST_ID"; then
			echo "Custom Metrics present for $NAMESPACE_ID; Setting Alerts"
			if [ "$METRIC_NAME" == "Disk" ]; then
				setDiskAlarmsLinux "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
			elif [ "$METRIC_NAME" == "Memory" ]; then
				setMemoryAlarms "$SNS_ARN" "$NAMESPACE_ID" "$METRIC_NAME""Utilization"
			fi
		else
			echo "Custom Metrics for $METRIC_NAME are not set on $INST_ID; Do it ASAP."
		fi
	done
fi
