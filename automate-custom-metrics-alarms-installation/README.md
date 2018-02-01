# Custom Metrics Alarms Auto Setup

This script is interactive and will prompt for the following:
* awscli profile
* awscli region
* Customer Name
* SNS ARN (for email/slack alerts), and
* Instance ID

This script makes use of `awless` tool along with `aws` CLI.

## Synopsis:

This script will take the input of Instance ID and will check/do the following:
1. Check if the instance is `Linux`/`Windows`
2. Check for custom metrics for this particular instance (I am using namespaces as `Linux/Disk`, `Linux/Memory`, `Windows/Disk` and `Windows/Memory`)
3. If the custom metrics (either one) found, run the functions accordingly for `Memory` and `Disk` alarms/alerts.
4. If the custom metrics (any one) are not present for this instance, then the script quits, yelling to install the custom metrics **ASAP**.

# NOTE:

1. `SNS_ARN` can be given multiple as comma separated value, *without spaces*.
2. Test and then use, although nothing disastrous will happen.
