# Automate Route53 entries using Shell Script
---

Alright ! How to deal with tons of Route53 entries to be created in AWS ?

**Two Ways**:

1. Using AWS Console, i.e., manually one by one
2. Using automation, i.e., using shell scripts or other automation tool (terraform/ansible/blah/blah).

For this, I am using shell scripting to `only add new` entries to Route53. I'll explain the code in sections below.

### Basic stuff

```Sh
#!/bin/bash

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
alias aws=''"$(which aws)"' --profile <PROFILE_NAME> --output text'
shopt -s expand_aliases
```

The above code will make use of proper **PATHs** and will not break any commands in the script (read `command not found`).

### Main Logic

```sh
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
		a|A)  		  		addArecord "$DNSNAME" "$DNSVALUE"		; sleep 5   ;;
		cname|CNAME)  		addCNAMErecord "$DNSNAME" "$DNSVALUE"	; sleep 5 ;;
		mx|MX)  		  	mxrecfunc ;;
		*)	echo "Work in progress; Do manually";;
	esac
done < "$DNSFILE"

```

The script takes 2 arguments as input to the script.

* `DNSFILE`: CSV file containing the DNS records in csv format. More details on this later
* `DOMAINNAME`: Domain name for which Hosted zone and DNS records are to be created.

#### Other variables:

* `TIMESTAMP`: Unique timestamp to create a hosted zone. The one I have used is in `epoch` format.
* `MXCOUNT`: To calculate the number of MX records present in CSV file. Used in functions later.

The above code will do the following in series of steps:

1. Create Hosted Zone and store the ID in `HOSTEDZONE_ID` variable.
2. For each line in the `DNSFILE` file, call the corresponding function to create the record. Currently, only `A`, `CNAME` and `MX` records can be updated by the script. For other's it will be updated later on Github itself.

### A Record function

```sh
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

```

#### Usage

addArecord `$DNSNAME` `$DNSVALUE`

Since AWS `change-resource-record-sets` command accepts JSON, so I had to create a JSON in a variable to use it. The function takes 2 arguments as input. 

**Example:**

addArecord `testexample.com` `1.2.3.4`

---

### CNAME Record

```sh
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
```

Similar is the case of CNAME record. <u>Only thing to take care of is this:</u>

addCNAMErecord `www.testexample.com` `test example.com`

and not

~~addCNAMErecord `testexample.com ` `www.testexample.com`~~

---

### MX Records

```sh
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
```

Updating MX records is tricky. The values can be 1 or more than 1. For DNS with single MX record is easy. However, updating with 2 MX records cause replacing of 1st MX with the 2nd one.



Here, we are using 3 functions `addMXrecord`, `addMultipleMXrecord` and `mxrecfunc`.

#### addMXrecord

```sh
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
```

The above code is similar to A records and CNAME records, and is applicable for 1 MX record only.

#### addMultipleMXrecord

```sh
addMultipleMXrecord () {
unset MX_RECORDS
while read -r line; do 
  MX_RECORDS+=( ""$(python -c 'import json, sys; print(json.dumps([{"Value": v} for v in sys.argv[1:]]))' "$line")"" )
done < <(grep -i MX "$DNSFILE" | cut -d, -f3)
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
```

Here, the code gets a little nasty. For multiple MX values, `ResourceRecords` require Key Value in JSON format. So to get the code in JSON, I had to use a small `python` snippet to get values in array.

End result:

```json
[
  {
    "Value": "1 A"
  },
  {
    "Value": "2 B"
  }
]
```

or 

```json
[{"Value":"1 A"},{"Value":"2 B"}]
```

Since the above have 2 values, it can be used to update MX records easily.

#### mxrecfunc

```sh
mxrecfunc() {
  if [[ "$MXCOUNT" == 1 ]]; then
    addMXrecord "$DNSNAME" "$DNSVALUE"
    sleep 5
  else
    addMultipleMXrecord
    sleep 5
  fi
}
```

The above function simply checks for the count of MX records in DNS file. If the count is 1, then `addMXrecord` is called, else `addMultipleMXrecord`.

---

### DNS File Contents/Format

```
testexample.com,A,1.2.3.4
qa.testexample.com,A,4.3.2.1
ftp.testexample.com,CNAME,testexample.com
www.testexample.com,CNAME,testexample.com
testexample.com,MX,5 testexample1.com
testexample.com,MX,10 testexample2.com
```

---

### Screenshots
#### Terminal Output

![](http://vrnchndk.in/images/r53-terminal-output.png)

#### AWS Console Output

![](http://vrnchndk.in/images/r53-gui-output.png)


Code is available on [Github](github.com)

---

## NOTES:

1.  I am not responsible for any command not working, it’s working for me as intended.
2.  Suggestions/Edits are welcome.
3.  Use of `Python` and `jq` are incorporated, make sure they are installed and configured properly.

