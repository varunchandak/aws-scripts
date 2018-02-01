#!/bin/bash

# This is a basic script to check for AWS IAM permissions and security groups which are open to world. This script also check the access key and password age and recommends the rotation of the same.

########################################################################################################
green='\033[1;32m' # OK
red='\033[1;31m' # CRITICAL
xx='\033[0m' # NO COLOR
yw='\033[1;33m' # HEADING
blue='\033[0;34m' # HIGHLIGHT
AWS_PROFILE="$1"
AWS_REGION="$2"
alias aws='aws --profile '"$AWS_PROFILE"' --region '"$AWS_REGION"' --output json'
shopt -s expand_aliases

usage() {
SCRIPT_NAME="$(basename $0)"
echo -e '
'"${green}"'Usage: '"$SCRIPT_NAME"' <AWSCLI PROFILE> <AWS_REGION>'"${xx}"'

Example:
'"${blue}"'./'"$SCRIPT_NAME${xx} ${red}clientname region${xx} - ${yw}Using clientname AWSCLI profile.${xx}"'
or,
'"${blue}"'./'"$SCRIPT_NAME${xx} ${red}default region${xx} - ${yw}Using default profile.${xx}"'

'"${blue}Note:${xx}
 - ${yw}the following packages are required for proper working of this script.${xx}
 	1. ${red}awscli${xx} configured with profiles.
 	2. ${red}jq${xx} for parsing output.
 	3. ${red}bc${xx} for calculating arithmetic values.
 - ${yw}this script must be run on linux machines with BASH, only. Won't work on MacOSX or windows.${xx}"'
'
}

if [[ "$#" -ne 2 ]]; then
	usage
else
	clear
	echo -e "${yw}Using profile${xx} ${blue}$AWS_PROFILE${xx}"
	sleep 5; clear
	########################################################################################################
	SECURITY_REPORT="security-report-$(date +%d%b%Y-%H%M).txt"
	echo -e "${yw}#################################################${xx}"
	echo -e "${yw}Starting Security check for the AWS account....${xx}" | tee "$SECURITY_REPORT"
	echo -e "${yw}#################################################${xx}" | tee -a "$SECURITY_REPORT"
	echo ""
	########################################################################################################
	# IAM
	echo -e "${blue}### IAM ###${xx}" | tee -a "$SECURITY_REPORT"
	echo -e "${yw}Generating credential report, please wait...${xx}"
	aws iam generate-credential-report > /dev/null 2>&1
	sleep 5
	aws iam get-credential-report --query 'Content' --output text | base64 -d > full-credential-report.csv

	## CHECK ROOT LOGIN MFA
	echo -e "${yw}### Checking ROOT Login MFA${xx}" | tee -a "$SECURITY_REPORT"
	if [[ "$(aws iam get-account-summary --query 'SummaryMap.AccountMFAEnabled')" -ne 1 ]]; then
		echo -e "${red}Root login MFA is not activated${xx}" | tee -a "$SECURITY_REPORT"
	else
		echo -e "${green}ROOT MFA IS ENABLED.${xx}" | tee -a "$SECURITY_REPORT"
	fi

	## Unused IAM Users (without Access Key and Password)
	echo -e "${yw}### Checking unused IAM users${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$5","$9}' full-credential-report.csv | grep 'N/A,false' | cut -d, -f1 | tee -a "$SECURITY_REPORT"

	## AWS Console login > 90 Days
	echo -e "${yw}### Checking AWS Console login > 90 Days${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$5}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "password_last_used"$ | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > password_details.csv
	IFS=','; while read -r USER_NAME PASS_DATE; do
		todate="$(date -d "$PASS_DATE" +%s)"
		cond="$(date +%s)"
		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
			echo -e "${blue}Last AWS Console Login:${xx} ${red}$AGE_TIME Days${xx}; Disable password for ${red}$USER_NAME${xx}" | tee -a "$SECURITY_REPORT"
		fi
	done < password_details.csv | sort -t' ' -k5

	## password age more than 90 days
#	echo -e "${yw}### Checking password age > 90 Days${xx}" | tee -a "$SECURITY_REPORT"
#	awk -F, '{print $1","$3}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "user_creation_time"$ | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > password_details.csv
#	IFS=','; while read -r USER_NAME PASS_AGE; do
#		todate="$(date -d "$PASS_AGE" +%s)"
#		cond="$(date +%s)"
#		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
#		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
#			echo -e "${blue}Password Age:${xx} ${red}$AGE_TIME Days${xx}; Change password for ${red}$USER_NAME${xx}" | tee -a "$SECURITY_REPORT"
#		fi
#	done < password_details.csv | sort -t' ' -k3

	## password last changed 90 days
	echo -e "${yw}### Checking password last changed > 90 Days${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$6}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "password_last_changed"$ -e '<root' | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > password_details.csv
	IFS=','; while read -r USER_NAME PASS_CHANGE; do
		todate="$(date -d "$PASS_CHANGE" +%s)"
		cond="$(date +%s)"
		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
			echo -e "${blue}Password Last Changed:${xx} ${red}$AGE_TIME Days ago.${xx}; Alert ${red}$USER_NAME${xx} to change password." | tee -a "$SECURITY_REPORT"
		fi
	done < password_details.csv | sort -t' ' -k4

	## users having access key 1 and needs rotation > 90 days
	echo -e "${yw}### Checking users having access key 1 and needs rotation > 90 days${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$10}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > password_details.csv
	IFS=','; while read -r USER_NAME ACCESS_KEY_LAST_USE; do
		todate="$(date -d "$ACCESS_KEY_LAST_USE" +%s)"
		cond="$(date +%s)"
		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
			echo -e "${blue}Access Key 1 created:${xx} ${red}$AGE_TIME Days${xx}; ${blue}Access Key 1 to be rotated for${xx} ${red}$USER_NAME${xx}" | tee -a "$SECURITY_REPORT"
		fi
	done < password_details.csv | sort -t' ' -k5

	## users having access key 2 and needs rotation > 90 days
	echo -e "${yw}### Checking users having access key 2 and needs rotation > 90 days${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$15}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > password_details.csv
	IFS=','; while read -r USER_NAME ACCESS_KEY_LAST_ROTATE; do
		todate="$(date -d "$ACCESS_KEY_LAST_ROTATE" +%s)"
		cond="$(date +%s)"
		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
			echo -e "${blue}Access Key 2 created:${xx} ${red}$AGE_TIME Days${xx}; ${blue}Access Key 2 to be rotated for${xx} ${red}$USER_NAME${xx}" | tee -a "$SECURITY_REPORT"
		fi
	done < password_details.csv | sort -t' ' -k5

	## IAM PASSWORD POLICY CHECK
	echo -e "${yw}### Checking IAM Password Policy${xx}" | tee -a "$SECURITY_REPORT"
	if ! aws iam get-account-password-policy > /dev/null 2>&1; then
		echo -e "${red}Password Policy is not set for IAM Users in this account.${xx}" | tee -a "$SECURITY_REPORT"
	else
		PASS_POLICY="$(aws iam get-account-password-policy --output json)"
		if [[ "$(echo -e "$PASS_POLICY" | jq '.PasswordPolicy.RequireLowercaseCharacters')" -ne "true" ]]; then
			echo -e "${red}Set policy to accept lowercase letters.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}lowercase letters are enabled.${xx}" | tee -a "$SECURITY_REPORT"
		fi
		if [[ "$(echo -e "$PASS_POLICY" | jq '.PasswordPolicy.RequireUppercaseCharacters')" -ne "true" ]]; then
			echo -e "${red}Set policy to accept uppercase letters.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}uppercase letters are enabled.${xx}" | tee -a "$SECURITY_REPORT"
		fi
		if [[ "$(echo -e "$PASS_POLICY" | jq '.PasswordPolicy.RequireSymbols')" -ne "true" ]]; then
			echo -e "${red}Set policy to accept symbol characters.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}Special characters are enabled.${xx}" | tee -a "$SECURITY_REPORT"
		fi
		if [[ "$(echo -e "$PASS_POLICY" | jq '.PasswordPolicy.RequireNumbers')" -ne "true" ]]; then
			echo -e "${red}Set policy to accept numeric characters.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}numeric characters are enabled.${xx}" | tee -a "$SECURITY_REPORT"
		fi
		if [[ "$(echo -e "$PASS_POLICY" | jq '.PasswordPolicy.MinimumPasswordLength')" -le "6" ]]; then
			echo -e "${red}Set policy to accept minimum password length more than 6 characters.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}Password length is set to more than 6 characters.${xx}" | tee -a "$SECURITY_REPORT"
		fi
	fi

	## IAM MFA CHECK
	## LIST OF USERS HAVING PASSWORD ENABLED BUT NOT MFA
	echo -e "${yw}### Checking LIST OF USERS HAVING PASSWORD ENABLED BUT NOT MFA${xx}" | tee -a "$SECURITY_REPORT"
	awk -F, '{print $1","$4","$8}' full-credential-report.csv | tail -n +2 | grep -v -e 'true,true' -e '<root_account>' | grep 'true,false' | cut -d, -f1 | tee -a "$SECURITY_REPORT"

	## IAM CHECK USER ATTACHED POLICIES
	# list groups and policies
	echo -e "${yw}### Checking groups and attached policies.${xx}" | tee -a "$SECURITY_REPORT"
	aws iam list-groups --output json | jq '.Groups[].GroupName' | tr -d '"' | while read -r line; do
		echo "$line"
		aws iam list-attached-group-policies --group-name "$line" --output json --query 'AttachedPolicies[].PolicyName' | jq -c .
	done | paste -d, - - | grep -v "\[\]$" | sed -e 's,\[,,g' -e 's,\],,g' | tee -a "$SECURITY_REPORT"

	echo -e "${yw}### Checking users and attached policies.${xx}" | tee -a "$SECURITY_REPORT"
	aws iam list-users --output json | jq '.Users[].UserName' | tr -d '"' | while read -r line; do
		echo "$line"
		aws iam list-attached-user-policies --user-name "$line" --query 'AttachedPolicies[].PolicyName' --output json | jq -c .
	done | paste -d, - - | grep -v "\[\]$" | sed -e 's,\[,,g' -e 's,\],,g' | tee -a "$SECURITY_REPORT"

	echo -e "${yw}### Checking users and attached groups.${xx}" | tee -a "$SECURITY_REPORT"
	aws iam list-users --output json | jq '.Users[].UserName' | tr -d '"' | while read -r line; do
		echo "$line"
		aws iam list-groups-for-user --user-name "$line" --query 'Groups[].GroupName' | jq -c .
	done | paste -d, - - | grep -v "\[\]$" | sed -e 's,\[,,g' -e 's,\],,g' | tee -a "$SECURITY_REPORT"

	########################################################################################################
	# CLOUDWATCH
	echo -e "${blue}### CLOUDWATCH ###${xx}" | tee -a "$SECURITY_REPORT"
	echo -e "${yw}### Checking Custom Metrics.${xx}" | tee -a "$SECURITY_REPORT"
	aws cloudwatch list-metrics --query 'Metrics[].Namespace' --output text | tr -s '\t' '\n' | sort | uniq | grep -e ^"Linux/" -e ^"Windows/" > existing-custom-metrics.csv

	while read -r CUSTOM_METRICS; do
		if ! grep -Fxq "$CUSTOM_METRICS" <(aws cloudwatch list-metrics --query 'Metrics[].Namespace' --output text | tr -s '\t' '\n' | sort | uniq | grep -e ^"Linux/" -e ^"Windows/"); then
			echo -e "${blue}$CUSTOM_METRICS${xx} ${red}metric is not installed in the EC2 Instances.${xx}" | tee -a "$SECURITY_REPORT"
		else
			echo -e "${green}$CUSTOM_METRICS${xx} ${red}metric is installed in the EC2 Instances (atleast 1).${xx}" | tee -a "$SECURITY_REPORT"
		fi
	done < <(echo -e "Linux/Disk\nLinux/Memory\nWindows/Disk\nWindows/Memory")

	########################################################################################################> /dev/null 2>&1
	# CLOUDTRAIL
	echo -e "${blue}### CLOUDTRAIL ###${xx}" | tee -a "$SECURITY_REPORT"
	if ! aws cloudtrail describe-trails --output json > /dev/null 2>&1; then
		echo -e "${red}CLOUDTRAIL is not setup for this account.${xx}" | tee -a "$SECURITY_REPORT"
	else
		echo -e "${green}CLOUDTRAIL is enabled for this account.${xx}" | tee -a "$SECURITY_REPORT"
		CLOUDTRAIL_DETAILS="$(aws cloudtrail describe-trails --output json)"
		if ! echo -e "$CLOUDTRAIL_DETAILS" | jq '.trailList[].S3BucketName' > /dev/null; then
			echo -e "${blue}Cloutrail${xx} ${red}logs${xx} ${blue}are not enabled for this account.${xx}" | tee -a "$SECURITY_REPORT"
		fi
		#if [[ "$(echo -e "$CLOUDTRAIL_DETAILS" | jq '.trailList[].IsMultiRegionTrail')" -ne "true" ]]; then
		if [[ "$(aws cloudtrail describe-trails --output text --query 'trailList[*].IsMultiRegionTrail')" -ne "True" ]]; then
			echo -e "${blue}Cloudtrail is not setup for ${xx} ${red}multi/all regions.${xx}" | tee -a "$SECURITY_REPORT"
		fi
	fi

	########################################################################################################
	# SECURITY GROUPS CHECK
	echo -e "${blue}### SECURITY GROUPS ###${xx}" | tee -a "$SECURITY_REPORT"
	echo -e "${yw}### Checking ports in security groups that are open to world (0.0.0.0/0)${xx}" | tee -a "$SECURITY_REPORT"
	aws ec2 describe-security-groups --filters --query 'SecurityGroups[*].[GroupName, IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]].ToPort]' | jq -c . | sed -e 's/\],\[/\n/g' -e 's/^\[\[//g' -e 's/\]\]//g' | grep -v '\[\]'$ | sed -e 's,\[,,g' -e 's,\],,g' | tee -a "$SECURITY_REPORT"

	########################################################################################################
	# VPC
	echo -e "${blue}### VPC FLOW LOGS ###${xx}" | tee -a "$SECURITY_REPORT"
	echo -e "${yw}### Checking flow logs enabled for the VPC${xx}" | tee -a "$SECURITY_REPORT"
	if ! aws ec2 describe-flow-logs > /dev/null 2>&1; then
		echo -e "${red}VPC Flow Logs are not enabled on this account${xx}" | tee -a "$SECURITY_REPORT"
	else
		echo -e "${green}VPC Flow Logs are enabled on this account.${xx}" | tee -a "$SECURITY_REPORT"
		if [[ -z "$(aws ec2 describe-flow-logs --query 'FlowLogs[].FlowLogId' --output text)" ]]; then
			echo -e "${red}VPC Flow Logs are not configured properly on this account${xx}" | tee -a "$SECURITY_REPORT"
		else
			aws ec2 describe-flow-logs --query 'FlowLogs[].FlowLogId' --output text | tr -s '\t' '\n' | tee -a "$SECURITY_REPORT"
		fi
	fi

	########################################################################################################
	# S3
	## CHECK BUCKETS WITH PUBLIC READ ACCESS
	echo -e "${blue}### S3 BUCKETS ###${xx}" | tee -a "$SECURITY_REPORT"
	echo -e "${yw}### Checking S3 buckets with public read access${xx}" | tee -a "$SECURITY_REPORT"
	aws s3 ls | awk '{print $NF}' | while read -r line; do
		if aws s3api get-bucket-acl --bucket "$line" --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`].Permission' | grep -q -i read; then
			echo -e "$line" | tee -a "$SECURITY_REPORT"
		fi
	done
	rm -f full-credential-report.csv iam-userlist.csv existing-custom-metrics.csv password_details.csv
	clear
	echo -e "${green}############################################################################################3####${xx}"
	echo -e "${green}Security Script has ended. Please send the $SECURITY_REPORT file to CloudCover representatives.${xx}"
	echo -e "${green}#################################################################################################${xx}"
fi
