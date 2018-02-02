# Alert unhealthy instances present in the ALB/ELB to slack

The script is used to report unhealthy hosts present in ALB/ELB on AWS to a specific slack channel.

Prerequisites:

* Slack Channel
* Slack Webhook URL
* AWS Role on EC2 (or IAM credentials in profile)

---
## check-unhealthy-hosts-alb.sh

This script will check unhealthy hosts in a particular `ALB`.

**Requirements**:
- Target Group ARN of the ALB to check for unhealthy hosts.

**Usage**:
```
./check-unhealthy-hosts-alb.sh <TARGET_GROUP_ARN> <AWS_PROFILE> <AWS_REGION>
```
**Example**:
```
./check-unhealthy-hosts-alb.sh arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/test-targetgroup/abcd1234 default ap-south-1
```
---
## check-unhealthy-hosts.sh

This script will check unhealthy hosts in a particular `ELB`.

**Requirements**:
- ELB Name to check for unhealthy hosts.

**Usage**:
```
./check-unhealthy-hosts.sh <ELB_NAME> <AWS PROFILE> <AWS_REGION>
```

**Example**:
```
./check-unhealthy-hosts.sh test-elb default ap-south-1
```
