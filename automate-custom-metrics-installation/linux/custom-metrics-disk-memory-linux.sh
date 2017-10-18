#!/bin/bash


export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:"$PATH"
alias aws=''`which aws`' --output text'
shopt -s expand_aliases
export AWS_DEFAULT_REGION="$(curl http://169.254.169.254/latest/meta-data/local-hostname 2> /dev/null | cut -d'.' -f2)"
export AWS_DEFAULT_OUTPUT="text"

INST_ID="$(curl http://169.254.169.254/latest/meta-data/instance-id)"

MemoryMetric() {
mem=$(bc <<< "scale=2; $(free -m  | grep ^Mem | awk '{print $3/$2*100}')/1")
aws cloudwatch put-metric-data \
	--metric-name "MemoryUtilization" \
	--unit Percent \
	--value "$mem" \
	--dimensions InstanceId="$INST_ID" \
	--namespace Linux/Memory
}

DiskMetric(){
aws cloudwatch put-metric-data \
	--metric-name "DiskUtilization" \
	--unit Percent \
	--value "$2" \
	--dimensions InstanceId="$INST_ID",Filesystem="$1",MountPath="$3" \
	--namespace Linux/Disk
}
###############################################################################################################

if [[ $1 == DiskMetric ]]; then
	# Starting Disk Logic
	# /dev/sda2 62 /VM
	# $1 = /dev/sda2
	# $2 = 62
	# $3 = /VM
	df -Pkh | grep "[0-9]%" | awk '{print $1" "$5" "$6}' | tr -d '%' | grep -f <(blkid | cut -d: -f1) | while read line; do
                DiskMetric $line
        done
elif [[ $1 == MemoryMetric ]]; then
        MemoryMetric
fi

unalias aws
