#!/bin/bash
##################################################################################################################
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'
alias aws=''`which aws`' --profile <TEST> --output text'
shopt -s expand_aliases
##################################################################################################################
# Script Logic for migrating single EC2 instance
SOURCE_INST_ID="$1" # i-source
SOURCE_REGION="$2" # ap-southeast-1
TARGET_REGION="$3" # ap-south-1
##################################################################################################################
#Migration of EC2 instance from another region
##################
#Assumptions:
#1. Same CIDR VPC present in <TARGET REGION>
##################
#Steps:
#1. Create image of <SOURCE EC2 INSTANCE>
DEST_INST_NAME="$(aws ec2 describe-instances \
 --region "$SOURCE_REGION" \
 --instance-ids "$SOURCE_INST_ID" \
 --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value')"

SOURCE_IMAGE="$(aws ec2 create-image \
 --region "$SOURCE_REGION" \
 --instance-id "$SOURCE_INST_ID" \
 --name "$DEST_INST_NAME"_"$(date +%d%b%Y)" \
 --description "$DEST_INST_NAME"_"$(date +%d%b%Y)" \
 --no-reboot)"
##################################################################################################################
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
 echo sleeping
 sleep 30
done
##################################################################################################################
#3. Copy Security Groups to <TARGET REGION>
#	Migration Steps Example:
#	1. Setup your AWS profile to point to your source VPC
#	   export AWS_DEFAULT_PROFILE=dev
#	2. Provide source Security Group ID and target VPC ID
#	   ./copysg.py --shell --vpc=vpc-xx77675a sg-335f31e5 > sg-335f31e5.sh
#	3. Setup your AWS profile to point to your target VPC
#	   export AWS_DEFAULT_PROFILE=test
#	4. Review generated shell script to make sure all looks good
#	   vi sg-335f31e5.sh
#	5. Run generated shell script to create the security group in target VPC
#	   ./sg-335f31e5.sh
#	6. Review newly created security group in target VPC
#	   aws ec2 describe-security-groups --query 'SecurityGroups[*].[VpcId, GroupId, GroupName]' --output text
TARGET_VPC_ID="$(aws ec2 describe-vpcs \
 --region "$TARGET_REGION" \
 --query 'Vpcs[*].VpcId')"
SG_ARRAY=($(aws ec2 describe-instances \
 --region "$SOURCE_REGION" \
 --instance-ids "$SOURCE_INST_ID" \
 --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' | tr -s '\t' ' '))
export AWS_DEFAULT_PROFILE="TESTPROFILE"
for SG_ID in "${SG_ARRAY[@]}"; do
 export AWS_DEFAULT_REGION="$SOURCE_REGION"
 /usr/bin/python \
 ../security_groups/copysg.py \
  --shell --vpc="$TARGET_VPC_ID" "$SG_ID" > "$SG_ID".sh
 export AWS_DEFAULT_REGION="$TARGET_REGION"
 /bin/bash "$SG_ID".sh
 rm -fv "$SG_ID".sh
done
unset AWS_DEFAULT_PROFILE
unset AWS_DEFAULT_REGION
##################################################################################################################
#4. Generate JSON of <SOURCE EC2 INSTANCE>
#extract JSONs of existing instances
aws ec2 describe-instances \
 --region "$SOURCE_REGION" \
 --instance-ids "$SOURCE_INST_ID" \
 --output json > "$SOURCE_INST_ID".json
##################################################################################################################
#5. Generate and Launch Instance with JSON

unset TARGETSG_ID
while read line; do
 COUNTER=0
 TARGETSG_ID+=("$(aws ec2 describe-security-groups --region "$TARGET_REGION" --filters Name=group-name,Values="$line" --query 'SecurityGroups[*].GroupId')")
 let COUNTER++
done < <(jq '.Reservations[].Instances[].SecurityGroups[].GroupName' "$SOURCE_INST_ID".json | tr -d \")

KEY_NAME="$(jq '.Reservations[].Instances[].KeyName' "$SOURCE_INST_ID".json | tr -d \")"
TARGET_INST_TYPE="$(jq '.Reservations[].Instances[].InstanceType' "$SOURCE_INST_ID".json | tr -d \")"
SOURCE_SUBNET="$(jq '.Reservations[].Instances[].SubnetId' "$SOURCE_INST_ID".json | tr -d \")"
TARGET_SUBNET="$(grep $SOURCE_SUBNET oldnew_subnets.csv | cut -d, -f2)"
PRIV_IP="$(jq '.Reservations[].Instances[].PrivateIpAddress' "$SOURCE_INST_ID".json | tr -d \")"

DEST_INST_ID="$(aws --region "$TARGET_REGION" ec2 run-instances \
 --image-id "$DEST_IMAGE" \
 --key-name "$KEY_NAME" \
 --security-group-ids ${TARGETSG_ID[@]} \
 --instance-type "$TARGET_INST_TYPE" \
 --subnet-id "$TARGET_SUBNET" \
 --private-ip-address "$PRIV_IP" \
 --no-ebs-optimized \
 --count 1 \
 --associate-public-ip-address \
 --query 'Instances[*].InstanceId')"
##################################################################################################################
#7. Allocate EIP and assign the newly launched instance
ALLOC_ID="$(aws --region "$TARGET_REGION" ec2 allocate-address --domain vpc --query 'AllocationId')"
aws --region "$TARGET_REGION" ec2 associate-address --instance-id "$DEST_INST_ID" --allocation-id "$ALLOC_ID"
##################################################################################################################
#8. assign tags
TAG_LIST="$(jq -c '.Reservations[].Instances[].Tags[]' "$SOURCE_INST_ID".json | while read line; do echo "$line" | tr -d \" | tr -d \{ | tr -d \} | tr -s ':' '=' | awk -F, '{print $2","$1}'; done | sed -e "/\s/ s/Value=/Value='/g" -e "/\s/ s/$/'/g" | tr -s '\n' ' ' | sed -e 's/\s$//')"

aws --region "$TARGET_REGION" ec2 create-tags --resources "$DEST_INST_ID" --tags $TAG_LIST
