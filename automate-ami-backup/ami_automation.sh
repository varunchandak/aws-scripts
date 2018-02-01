#!/bin/bash
#Script to create AMI of server on daily basis and deleting AMI older than n no of days

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/snap/bin

alias aws=''$(which aws)' --output text --region ap-southeast-1'
shopt -s expand_aliases

createAMI() {
        #To create a unique AMI name for this script
        INST_NAME="$(aws ec2 describe-instances --filters Name=instance-id,Values=$1 --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value')"
        INST_TAG="$INST_NAME"_"$(date +%d%b%y)"
        echo -e "Starting the Daily AMI creation: $INST_TAG\n"

        #To create AMI of defined instance
        AMI_ID=$(aws ec2 create-image --instance-id "$1" --name "$INST_TAG" --description "$1"_"$(date +%d%b%y)" --no-reboot)
        echo "New AMI Id is: $AMI_ID"
        echo "Waiting for 0.5 minutes"
        sleep 30

        #Renaming AMI and its Snapshots
        aws ec2 create-tags --resources "$AMI_ID" --tags Key=Name,Value="$INST_TAG"
        aws ec2 describe-images --image-id "$AMI_ID" --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' | tr -s '\t' '\n' > /tmp/newsnaplist.txt
        while read SNAP_ID; do
                aws ec2 create-tags --resources "$SNAP_ID" --tags Key=Name,Value="$INST_TAG"
        done < /tmp/newsnaplist.txt

        #Finding AMI older than n which needed to be removed
        if [[ $(aws ec2 describe-images --filters Name=description,Values="$1"_"$(date +%d%b%y --date ''$2' days ago')" --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' | tr -s '\t' '\n') ]]
        then
                AMIDELTAG="$1"_"$(date +%d%b%y --date ''$2' days ago')"

                #Finding Image ID of instance which needed to be Deregistered
                AMIDELETE=$(aws ec2 describe-images --filters Name=description,Values="$AMIDELTAG" --query 'Images[*].ImageId' | tr -s '\t' '\n')

                #Find the snapshots attached to the Image need to be Deregister
                aws ec2 describe-images --filters Name=image-id,Values="$AMIDELETE" --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' | tr -s '\t' '\n' > /tmp/snap.txt

                #Deregistering the AMI
                aws ec2 deregister-image --image-id "$AMIDELETE"

                #Deleting snapshots attached to AMI
                while read SNAP_DEL; do
                        aws ec2 delete-snapshot --snapshot-id "$SNAP_DEL"
                done < /tmp/snap.txt
        else
                echo "No AMI present"
        fi
}

###################################################################
########## Call the instance function below as shown ##############
###################################################################

IFS=','
grep -v '^#' /root/cloudcover/ami_automation/instanceList.csv | while read -r INST_ID RETENTION; do
        createAMI $INST_ID $RETENTION
done


######### Removing temporary files
rm -f /tmp/snap.txt /tmp/newsnaplist.txt