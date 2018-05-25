# get-temporary-access-secret-key

This script will generate a pair of access key and secret key with `SESSION_TOKEN` to run scripts which do not have Assume Role facility. The script takes 2 inputs, AWS profile name and AWS region.

Example output:
```
export AWS_DEFAULT_REGION=ap-southeast-1	(you can change this without re-running the script)
export AWS_ACCESS_KEY="ASIAAccessKeyId76VA"
export AWS_SECRET_KEY="fH5C1IQzSecretAccessKeyO6CuQKW"
export AWS_SESSION_TOKEN="FQSessionTokenYghVyiHnpjVBQ=="
export AWS_DEFAULT_OUTPUT=text
```

Just copy paste the above output in a terminal and you are good to go. Make sure to input ROLENAME in the script.
