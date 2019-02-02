# Automatically update ASG with latest image and launch configuration

This script will do the following (in order):
1. Get a list of instances running inside the autoscaling group
2. Create an AMI of the particular instance and store AMI ID
3. Fetch the launch configuration name to an autoscaling group (passed as parameter to script)
4. Create a new launch configuration with the updated image
5. Assign the Launch Configuration to the existing Auto Scaling Group (ASG)
6. Removal of old Launch Configurations (commented for now)

---

## NOTES:

* When you change the launch configuration for your Auto Scaling group, any new instances are launched using the new configuration parameters, but existing instances are not affected. This is the default configuration.
* **RUN THIS ON TEST ENVIRONMENT FIRST. I AM NOT RESPONSIBLE FOR ANY UNINTENDED DAMAGE.**