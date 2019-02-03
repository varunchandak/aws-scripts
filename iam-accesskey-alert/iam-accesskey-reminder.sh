#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/snap/bin:"$PATH"
AWS_PROFILE="$1"
alias aws=''`which aws`' --profile '"$AWS_PROFILE"''
shopt -s expand_aliases
ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

usage() {
	echo 'This script is used to send email alerts to the IAM users configured with email addresses to login to AWS console.
Note:
- This is a custom script with `sendmail` AND `sendEmail` configured with SES.

Usage:
./script.sh <AWS_PROFILE> <FROM_ADDRESS>

Example:
./script.sh someawsprofile noreply@vrnchndk.in

Notes:
- FROM_ADDRESS must be a SES verified email address, else the mailer will fail.
- This script assumes that the IAMUSER name is in email ID format.
- Install `sendEmail` on the linux box to send email.
- add SES SMTP credentials in the script to send email. `SES_USERNAME` and `SES_PASSWORD`
'
}

if [ "$#" -ne 2 ]; then
	usage
else
	SES_USERNAME=""
	SES_PASSWORD=""
	FROM_ADDRESS="$2"
	
	MailIt() {
		EMAILMESSAGE="$(echo -e 'Hello '"$IAMUSER"',\n\nThis is to remind you that your AWS Access Key pair(s) rotation is due pending. Please login to AWS account, generate a fresh pair and remove the old key your self to avoid any inconvenience. \n\nSign-in URL: https://'"$ACCOUNT_ID"'.signin.aws.amazon.com/console\n\n')"
	        sendemail \
	                -o tls=yes \
	                -xu "$SES_USERNAME" \
	                -xp "$SES_PASSWORD" \
	                -s email-smtp.us-east-1.amazonaws.com:587 \
	                -f "$FROM_ADDRESS" \
	                -t "$1" \
	                -cc "$FROM_ADDRESS" \
	                -u "IMPORTANT - Access Key Rotation Pending (ACCOUNT: $AWS_PROFILE)" \
	                -m "$EMAILMESSAGE"
	        sleep 2
	}
	
	aws iam generate-credential-report
	sleep 15
	aws iam get-credential-report --query 'Content' --output text | base64 --decode > full-credential-report.csv
	
	awk -F, '{print $1","$10}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -v OFS=, 'NR=1{$2=substr($2,1,10)}1' > /tmp/password_details.csv
	# output:
	# noreply@vrnchndk.in,2019-01-14
	
	IFS=','
	while read -r USER_NAME ACCESS_KEY_LAST_USE; do
		todate="$(date -d "$ACCESS_KEY_LAST_USE" +%s)"
		cond="$(date +%s)"
		AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
		if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
			MailIt "$IAMUSER"
		fi
	done < password_details.csv
	
	# Check for another key
	awk -F, '{print $1","$15}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -v OFS=, 'NR=1{$2=substr($2,1,10)}1' > /tmp/password_details.csv
	# output:
	# noreply@vrnchndk.in,2019-01-14
	
	IFS=','
	while read -r USER_NAME ACCESS_KEY_LAST_USE; do
	        todate="$(date -d "$ACCESS_KEY_LAST_USE" +%s)"
	        cond="$(date +%s)"
	        AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
	        if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
	                MailIt "$IAMUSER"
	        fi
	done < password_details.csv
	rm -rfv full-credential-report.csv
fi
