# Migrating EC2 Instance between regions



This shell script will migrate EC2 instance from 1 region to another. Basic steps are as follows:

1. Generate JSON of `<SOURCE EC2 INSTANCE>`.
2. Create image of `<SOURCE EC2 INSTANCE>`.
3. Copy image to `<TARGET REGION>`.
4. Copy Security Groups to `<TARGET REGION>` using python script mentioned [here](http://cloudarchitect.net/articles/45).
5. Launch instance in `<TARGET REGION>` with the values from JSON created in **Step 1**.

### Assumptions:

1. Same CIDR VPC/Subnet present in `<TARGET REGION>`. Without this, the `<PRIV_IP>` variable in the script has to be removed/commented.

### Notes

1. You can manually copy security groups first and comment **Step 4** in script.
2. Make sure to follow **Step 4** carefully.
3. *I am not responsible for any damages done.*