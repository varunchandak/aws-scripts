#!/bin/bash

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
alias aws=''"$(which aws)"' --profile cloudcover --output text'
shopt -s expand_aliases

addArecord () {
# Add A records
ARECJSON="$(echo '{
	"Comment": "A Record for '"$1"'",
	"Changes": [
	{
		"Action": "CREATE",
		"ResourceRecordSet": {
			"Name": "'"$1"'",
			"Type": "A",
			"TTL": 300,
			"ResourceRecords": [
			{
				"Value": "'"$2"'"
			}
			]
		}
	}
	]
}')"

aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONE_ID" --change-batch "$ARECJSON"
}

addCNAMErecord () {
# Add CNAME records
CNAMERECJSON="$(echo '{
  "Comment": "CNAME Record for '"$2"'",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "'"$1"'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "'"$2"'"
          }
        ]
      }
    }
  ]
}')"
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONE_ID" --change-batch "$CNAMERECJSON"
}

addMXrecord () {

# Add MX records
MXRECJSON="$(echo -e '{
  "Comment": "MX Record for '"$DOMAINNAME"'",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "'"$DOMAINNAME"'",
        "Type": "MX",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "'"$2"'"
          }
        ]
      }
    }
  ]
}')"
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONE_ID" --change-batch "$MXRECJSON"
}

addMultipleMXrecord () {
unset MX_RECORDS
while read -r line; do 
  MX_RECORDS+=( ""$(python -c 'import json, sys; print(json.dumps([{"Value": v} for v in sys.argv[1:]]))' "$line")"" )
done < <(grep -i MX "$DNSFILE" | cut -d, -f3)
#while [[ "$COUNTER" -lt "${#TEMPARRAY[@]}" ]]; do
#  MX_RECORDS+=( "$(python -c 'import json, sys; print(json.dumps([{"Value": v} for v in sys.argv[1:]]))' "${TEMPARRAY["$COUNTER"]}")" )
#  let COUNTER++              
#done
DNSVALUES="$(echo "${MX_RECORDS[@]}" | jq -c -s add)"

# Add MX records
MXRECJSON="$(echo -e '{
  "Comment": "MX Record for '"$DOMAINNAME"'",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "'"$DOMAINNAME"'",
        "Type": "MX",
        "TTL": 300,
        "ResourceRecords": '"$DNSVALUES"'
      }
    }
  ]
}')"
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONE_ID" --change-batch "$MXRECJSON"
}

mxrecfunc() {
  if [[ "$MXCOUNT" == 1 ]]; then
    addMXrecord "$DNSNAME" "$DNSVALUE"
    sleep 5
  else
    addMultipleMXrecord
    sleep 5
  fi
}
#####################################################################################################################
# testexample.com,A,1.2.3.4
# qa.testexample.com,A,4.3.2.1
# ftp.testexample.com,CNAME,testexample.com
# www.testexample.com,CNAME,testexample.com
# testexample.com,MX,5 testexample1.com
# testexample.com,MX,10 testexample1.com

DNSFILE="$2"
DOMAINNAME="$1"
TIMESTAMP=$(date +%s)
export MXCOUNT=$(cut -d, -f2 "$DNSFILE" | grep -i -c MX)

# Create Hosted Zone
HOSTEDZONE_ID="$(aws route53 create-hosted-zone --name "$DOMAINNAME" --caller-reference "$TIMESTAMP" --query 'HostedZone.Id' | cut -d\/ -f3)"
sleep 5
IFS=','
while read DNSNAME DNSTYPE DNSVALUE
do
	case "$DNSTYPE" in
		a|A)				      addArecord "$DNSNAME" "$DNSVALUE"		; sleep 5   ;;
		cname|CNAME)  		addCNAMErecord "$DNSNAME" "$DNSVALUE"	; sleep 5 ;;
		mx|MX)  mxrecfunc ;;
		*)	echo "Work in progress; Do manually";;
	esac
done < "$DNSFILE"
