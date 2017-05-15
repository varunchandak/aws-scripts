# Migration Steps Example:

1. Setup your AWS profile to point to your source VPC:

`export AWS_DEFAULT_PROFILE=dev`

2. Provide source Security Group ID and target VPC ID

`./copysg.py --shell --vpc=vpc-xx77675a sg-335f31e5 > sg-335f31e5.sh`

3. Setup your AWS profile to point to your target VPC

`export AWS_DEFAULT_PROFILE=test`

4. Review generated shell script to make sure all looks good

`vi sg-335f31e5.sh`

5. Run generated shell script to create the security group in target VPC

`./sg-335f31e5.sh`

6. Review newly created security group in target VPC

```
aws ec2 describe-security-groups \
	--query 'SecurityGroups[*].[VpcId, GroupId, GroupName]' \
	--output text
```