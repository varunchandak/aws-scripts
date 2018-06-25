# AWS CLI Access for IAM User with MFA

This script is used to generate temporary credentials for IAM user who has MFA enabled. By default, MFA enabled users are unable to access the CLI directly. Hence, this script comes in handy and generates temporary `ACCESS KEY`/`SECRET KEY` with 4 hours access (hardcoded; can be changed).

## Usage:

The script takes 3 inputs in the following order:

* IAM Username
* MFA Code (from device)
* Account ID (12 digit code)

## Example output:

```
export AWS_ACCESS_KEY="ASIAAccessKeyId76VA"
export AWS_SECRET_KEY="fH5C1IQzSecretAccessKeyO6CuQKW"
export AWS_SESSION_TOKEN="FQSessionTokenYghVyiHnpjVBQ=="
export AWS_DEFAULT_REGION=ap-southeast-1
export AWS_DEFAULT_OUTPUT=json
```
Just copy paste the above output in a terminal and you are good to go.

## Notes:

* You can change the region without re-running the script.