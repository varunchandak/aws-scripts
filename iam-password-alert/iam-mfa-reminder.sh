#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/snap/bin:"$PATH"
AWS_PROFILE="$1"
alias aws=''`which aws`' --profile '"$AWS_PROFILE"''
shopt -s expand_aliases

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

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
aws iam generate-credential-report
sleep 15
aws iam get-credential-report --query 'Content' --output text | base64 --decode > full-credential-report.csv

awk -F, '{print $1","$4","$8}' full-credential-report.csv | tail -n +2 | grep -v -e 'true,true' -e '<root_account>' | grep 'true,false' | cut -d, -f1 | grep @ | while read IAMUSER; do
	EMAILMESSAGE="$(echo -e 'Hello '"$IAMUSER"',\n\nIt looks like you havent enabled MFA for login. It is recommended to do so at the earliest to prevent any account misuse.\n\nSign-in URL: https://'"$ACCOUNT_ID"'.signin.aws.amazon.com/console\n\n')"
	sendemail \
		-o tls=yes \
		-xu "$SES_USERNAME" \
		-xp "$SES_PASSWORD" \
		-s email-smtp.us-east-1.amazonaws.com:587 \
		-f "$FROM_ADDRESS" \
		-t "$IAMUSER" \
		-cc "$FROM_ADDRESS" \
		-u "IMPORTANT - Enable MFA for AWS Console (ACCOUNT: $AWS_PROFILE)" \
		-m "$EMAILMESSAGE"
	sleep 2
done
rm -rfv full-credential-report.csv
fi
