#!/bin/bash

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

SOURCE_INST_ID="$1"
SOURCE_REGION="$2"
TARGET_REGION="$3"
AWS_PROFILE="$4"

alias aws=''`which aws`' --profile '"$AWS_PROFILE"' --output text'
shopt -s expand_aliases

# get name of source instance
DEST_INST_NAME="$(aws ec2 describe-instances \
	--region "$SOURCE_REGION" \
	--instance-ids "$SOURCE_INST_ID" \
	--query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value')"

# Create image from source instance to copy to target region
SOURCE_IMAGE="$(aws ec2 create-image \
	--region "$SOURCE_REGION" \
	--instance-id "$SOURCE_INST_ID" \
	--name "$DEST_INST_NAME"_"$(date +%d%b%Y)" \
	--description "$DEST_INST_NAME"_"$(date +%d%b%Y)" \
	--no-reboot)"

#2. Copy image to <TARGET REGION>
while true; do
 AMI_STATE="$(aws ec2 describe-images \
	 --region "$SOURCE_REGION" \
	 --filters Name=image-id,Values="$SOURCE_IMAGE" \
	 --query 'Images[*].State')"

 if [ "$AMI_STATE" == "available" ]; then
  DEST_IMAGE="$(aws ec2 copy-image \
	  --region "$TARGET_REGION" \
	  --source-region "$SOURCE_REGION" \
	  --source-image-id "$SOURCE_IMAGE" \
	  --name "$DEST_INST_NAME - Copied from $SOURCE_REGION" \
	  --description "$DEST_INST_NAME - Copied from $SOURCE_REGION")"
  break
 fi
 echo 'sleeping 15 seconds'; sleep 15
done

# Create source instance JSON
aws ec2 describe-instances \
	--region "$SOURCE_REGION" \
	--instance-ids "$SOURCE_INST_ID" \
	--output json > "$SOURCE_INST_ID".json

# Get the source security group id
SOURCE_SECGROUP_ID="$(jq '.Reservations[].Instances[].SecurityGroups[].GroupId' "$SOURCE_INST_ID".json | tr -d \")"

# Get the source security group name
SOURCE_SECGROUP_NAME="$(aws ec2 describe-security-groups \
	--group-id "$SOURCE_SECGROUP_ID" \
	--region "$SOURCE_REGION" \
	--query 'SecurityGroups[*].GroupName')"

# Get the target security group id
TARGET_SECGROUP_ID="$(aws ec2 describe-security-groups \
	--region "$TARGET_REGION" \
	--query 'SecurityGroups[*].[GroupName, GroupId]' | tr -s '\t' '\n' | paste -d, - - | grep "$SOURCE_SECGROUP_NAME" | cut -d, -f2-)"

# Set security group id in migration JSON
cat "$SOURCE_INST_ID".json | jq --arg TARGET_SECGROUP_ID "$TARGET_SECGROUP_ID" '.Reservations[].Instances[] | { DryRun: false, ImageId, KeyName, InstanceType, SubnetId, DisableApiTermination, PrivateIpAddress, EbsOptimized, "SecurityGroupIds":[$TARGET_SECGROUP_ID]}' > migration-"$SOURCE_INST_ID".json

##################################################################
# change instance type if the source instance type is not available in the target region
#sed -i 's,m3.xlarge,m4.xlarge,g' migration-"$SOURCE_INST_ID".json
##################################################################

# capture tags for the source instance so that we are not missing anything
cat "$SOURCE_INST_ID".json | jq '.Reservations[].Instances[] | { DryRun: false, Tags }' > tags-"$SOURCE_INST_ID".json
# compare subnets for both regions on the basis of cidr input
aws ec2 describe-subnets \
	--region "$SOURCE_REGION" \
	--query 'Subnets[*].CidrBlock' | tr -s '\t' '\n' | sort | while read CIDR_BLOCK; do
 paste -d, \
 <(aws --region "$SOURCE_REGION" ec2 describe-subnets --filters Name=cidr-block,Values="$CIDR_BLOCK" --query 'Subnets[*].SubnetId') \
 <(aws --region "$TARGET_REGION" ec2 describe-subnets --filters Name=cidr-block,Values="$CIDR_BLOCK" --query 'Subnets[*].SubnetId')
done | sort -t, -k1 > oldnew_subnets.csv
IFS=','
# replace the source subnet with target subnet
while read -r OLDSUBNET NEWSUBNET; do
	sed -i 's/'"$OLDSUBNET"'/'"$NEWSUBNET"'/g' migration-"$SOURCE_INST_ID".json
done < oldnew_subnets.csv

# Launch instance using the JSON
DEST_INST_ID="$(aws ec2 run-instances \
	--region "$TARGET_REGION" \
	--cli-input-json file://migration-"$SOURCE_INST_ID".json \
	--query 'Instances[*].InstanceId')"
if [ ! -z "$DEST_INST_ID" ]; then
	#7. Allocate EIP and assign the newly launched instance
	ALLOC_ID="$(aws ec2 allocate-address \
		--region "$TARGET_REGION" \
		--domain vpc \
		--query 'AllocationId')"
	aws ec2 associate-address \
		--region "$TARGET_REGION" \
		--instance-id "$DEST_INST_ID" \
		--allocation-id "$ALLOC_ID"
	# assign tags
	aws ec2 create-tags \
		--region "$TARGET_REGION" \
		--resources "$DEST_INST_ID" \
		--cli-input-json file://tags-"$SOURCE_INST_ID".json
else
	echo "Unable to launch and tag EC2 instance using migration-$SOURCE_INST_ID.json"
fi
