#!/bin/bash
##################################################################################################################
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'
alias aws=''`which aws`' --profile <PROFILE_NAME> --output text'
shopt -s expand_aliases

# IP/SUBNET Calculation Function
# MAIN URL: https://stackoverflow.com/a/28058660/2732674
ipcal() {
	############################
	##  Methods
	############################
	prefix_to_bit_netmask() {
	    prefix=$1;
	    shift=$(( 32 - prefix ));

	    bitmask=""
	    for (( i=0; i < 32; i++ )); do
	        num=0
	        if [ $i -lt $prefix ]; then
	            num=1
	        fi

	        space=
	        if [ $(( i % 8 )) -eq 0 ]; then
	            space=" ";
	        fi

	        bitmask="${bitmask}${space}${num}"
	    done
	    echo $bitmask
	}

	bit_netmask_to_wildcard_netmask() {
	    bitmask=$1;
	    wildcard_mask=
	    for octet in $bitmask; do
	        wildcard_mask="${wildcard_mask} $(( 255 - 2#$octet ))"
	    done
	    echo $wildcard_mask;
	}

	check_net_boundary() {
	    net=$1;
	    wildcard_mask=$2;
	    is_correct=1;
	    for (( i = 1; i <= 4; i++ )); do
	        net_octet=$(echo $net | cut -d '.' -f $i)
	        mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)
	        if [ $mask_octet -gt 0 ]; then
	            if [ $(( $net_octet&$mask_octet )) -ne 0 ]; then
	                is_correct=0;
	            fi
	        fi
	    done
	    echo $is_correct;
	}

	#######################
	##  MAIN
	#######################
	OPTIND=1;
	getopts "fibh" force;

	shift $((OPTIND-1))
	if [ $force = 'h' ]; then
	    echo ""
	    exit
	fi

	if [ $force = 'i' ] || [ $force = 'b' ]; then

	    old_IPS=$IPS
	    IPS=$'\n'
	    lines=($(cat $1)) # array
	    IPS=$old_IPS
	        else
	            lines=$@
	fi

	for ip in ${lines[@]}; do
	    net=$(echo $ip | cut -d '/' -f 1);
	    prefix=$(echo $ip | cut -d '/' -f 2);
	    do_processing=1;

	    bit_netmask=$(prefix_to_bit_netmask $prefix);

	    wildcard_mask=$(bit_netmask_to_wildcard_netmask "$bit_netmask");
	    is_net_boundary=$(check_net_boundary $net "$wildcard_mask");

	    if [ $force = 'f' ] && [ $is_net_boundary -ne 1 ] || [ $force = 'b' ] && [ $is_net_boundary -ne 1 ] ; then
	        read -p "Not a network boundary! Continue anyway (y/N)? " -n 1 -r
	        echo    ## move to a new line
	        if [[ $REPLY =~ ^[Yy]$ ]]; then
	            do_processing=1;
	        else
	            do_processing=0;
	        fi
	    fi

	    if [ $do_processing -eq 1 ]; then
	        str=
	        for (( i = 1; i <= 4; i++ )); do
	            range=$(echo $net | cut -d '.' -f $i)
	            mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)
	            if [ $mask_octet -gt 0 ]; then
	                range="{$range..$(( $range | $mask_octet ))}";
	            fi
	            str="${str} $range"
	        done
	        ips=$(echo $str | sed "s, ,\\.,g"); ## replace spaces with periods, a join...

	        eval echo $ips | tr ' ' '\n'
	else
	exit
	    fi

	done
}

# Script Logic for migrating single EC2 instance
SOURCE_INST_ID="$1" # i-source
SOURCE_REGION="$2" # ap-southeast-1
TARGET_REGION="$3" # ap-south-1

#Migration of EC2 instance from another region
#Assumptions:
#1. Same CIDR VPC present in <TARGET REGION>

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
 --description "$DEST_INST_NAME"_"$(date +%d%b%Y)" --no-reboot)"

#2. Copy image to <TARGET REGION>
while true; do
 AMI_STATE="$(aws ec2 describe-images --region "$SOURCE_REGION" --filters Name=image-id,Values="$SOURCE_IMAGE" --query 'Images[*].State')"
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

#4. Generate JSON of <SOURCE EC2 INSTANCE>
#extract JSONs of existing instances
aws ec2 describe-instances \
 --region "$SOURCE_REGION" \
 --instance-ids "$SOURCE_INST_ID" \
 --output json > "$SOURCE_INST_ID".json

#5. Modify JSON with <TARGET EC2 INSTANCE> details
cat "$SOURCE_INST_ID".json | jq --arg DEST_IMAGE "$DEST_IMAGE" '.Reservations[].Instances[] | { DryRun: false, ImageId: $DEST_IMAGE, KeyName, SecurityGroups, InstanceType, SubnetId, DisableApiTermination, EbsOptimized }' | sed 's/null/true/g' > migration-"$SOURCE_INST_ID".json

#json for tagging
cat "$SOURCE_INST_ID".json | jq '.Reservations[].Instances[] | { DryRun: false, Resources, Tags }' > tags-"$SOURCE_INST_ID".json
##################################################################################################################
#change subnets
export SOURCE_PRIV_IP="$(aws ec2 describe-instances \
	--region "$SOURCE_REGION" \
	--instance-ids "$SOURCE_INST_ID" \
	--query 'Reservations[*].Instances[*].PrivateIpAddress')"
IFS=','
aws ec2 describe-subnets --region "$TARGET_REGION" --query 'Subnets[].[SubnetId, CidrBlock]' | tr -s '\t' ',' | while read SUBNET_ID SUBNET_CIDR; do
 if ipcal "$SUBNET_CIDR" | grep -q "$SOURCE_PRIV_IP"; then
 	echo "$NEW_SUBNET_ID" > "$NEW_SUBNET_ID".txt
 fi
done
unset IFS
NEW_SUBNET_ID="$(cat subnet-*.txt)"
##################################################################################################################
#change security groups
#source security group name
SOURCE_SECGROUP_ID="$(jq '.Reservations[].Instances[].SecurityGroups[].GroupId' "$SOURCE_INST_ID".json | tr -d \")"
SOURCE_SECGROUP_NAME="$(aws ec2 describe-security-groups --group-id "$SOURCE_SECGROUP_ID" --region "$SOURCE_REGION" --output text --query 'SecurityGroups[*].[GroupName]')"
TARGET_SECGROUP_ID="$(aws ec2 describe-security-groups --region "$TARGET_REGION" --output text --query 'SecurityGroups[*].[GroupName, GroupId]' | tr -s '\t' '\n' | paste -d, - - | grep "$SOURCE_SECGROUP_NAME" | cut -d, -f2)"

# final JSON
cat "$SOURCE_INST_ID".json | jq \
	--arg TARGET_SECGROUP_ID "$TARGET_SECGROUP_ID" \
	--arg DEST_IMAGE "$DEST_IMAGE" \
	--arg NEW_SUBNET_ID "$NEW_SUBNET_ID" '.Reservations[].Instances[] | { DryRun: false, ImageId: $DEST_IMAGE, KeyName, InstanceType, SubnetId: $NEW_SUBNET_ID, DisableApiTermination: true, EbsOptimized, "SecurityGroupIds":[$TARGET_SECGROUP_ID]}' > migration-"$SOURCE_INST_ID".json

#6. Launch Instance with JSON
while true; do
	AMI_STATE="$(aws ec2 describe-images --region "$TARGET_REGION" --filters Name=image-id,Values="$DEST_IMAGE" --query 'Images[*].State')"
	if [ "$AMI_STATE" == "available" ]; then
		DEST_INST_ID="$(aws --region "$TARGET_REGION" ec2 run-instances --cli-input-json file://migration-"$SOURCE_INST_ID".json --query 'Instances[*].InstanceId')"
		#7. Allocate EIP and assign the newly launched instance
		ALLOC_ID="$(aws --region "$TARGET_REGION" ec2 allocate-address --domain vpc --query 'AllocationId')"
		sleep 30
		aws --region "$TARGET_REGION" ec2 associate-address --instance-id "$DEST_INST_ID" --allocation-id "$ALLOC_ID"

		#8. assign tags
		aws --region "$TARGET_REGION" ec2 create-tags --resources "$DEST_INST_ID" --cli-input-json file://tags-"$SOURCE_INST_ID".json

		# temp files removal
		rm -rf subnet-*.txt tags-"$SOURCE_INST_ID".json "$SOURCE_INST_ID".json migration-"$SOURCE_INST_ID".json
break
fi
echo 'sleeping 15 seconds'; sleep 15
done




