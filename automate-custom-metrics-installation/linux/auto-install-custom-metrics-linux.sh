#!/bin/bash

# This is a script to setup custom metrics on linux machines.
# Prerequisites:
# 1. This script must be run as root user, not sudo user.
# 2. AWS Cloudwatch credentials must be set. Role highly preferred.

# Installing required packages, Production Safe.
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:"$PATH"

YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)

if [[ ! -z $YUM_CMD ]]; then
	yum install -y bc blkid dos2unix
	wget https://bootstrap.pypa.io/get-pip.py; python get-pip.py
	pip install --upgrade pip
	pip install --upgrade awscli
elif [[ ! -z $APT_GET_CMD ]]; then
	apt-get update &> /dev/null
	apt-get install -y bc blkid dos2unix
	wget https://bootstrap.pypa.io/get-pip.py; python get-pip.py
	pip install --upgrade pip
	pip install --upgrade awscli
else
	echo "error can't install packages"
	exit 1;
fi

#Set Cloudwatch aws profile (use a role)
export AWS_DEFAULT_REGION="$(curl http://169.254.169.254/latest/meta-data/local-hostname 2> /dev/null | cut -d'.' -f2)"
export AWS_DEFAULT_OUTPUT="text"

# Downloading the script
mkdir /root/scripts/
#mkdir /root/.aws/
cd /root/scripts/
rm -f CustomMetricsMemoryDisk_v2.sh custom-metrics-disk-memory-linux.sh
wget https://s3.ap-south-1.amazonaws.com/cldcvr-custom-metrics/Linux/Disk_RAM/custom-metrics-disk-memory-linux.sh
dos2unix /root/scripts/custom-metrics-disk-memory-linux.sh
chmod +x /root/scripts/custom-metrics-disk-memory-linux.sh

# Setting up cron jobs
crontab -l | { cat; echo -e "* * * * *\t/bin/bash /root/scripts/custom-metrics-disk-memory-linux.sh DiskMetric"; } | crontab -
crontab -l | { cat; echo -e "* * * * *\t/bin/bash /root/scripts/custom-metrics-disk-memory-linux.sh MemoryMetric"; } | crontab -

# Check output
clear
crontab -l
