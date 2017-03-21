# Automate AWS AMI backups with Retention Period of `n` Days

Normally, we get requests to enable AMI backups and keep them for last 7 days or 30 days, etc. As it is not feasible to do this manually, it's best to automate this process.

When we say automation, first thing that comes to mind is **DevOps**, where we can use different tools such as `Ansible` or `Chef` or `Puppet`. Since, I like to do things in Shell Script, I'll be sharing the script here.

This script make use of an additional CSV file, which has the content as below:

```
#InstanceID,RetentionDays
i-b060363e,2
i-f10f5e7f,2
i-07d41dc8,2
i-715b81be,2
```

The above CSV has 2 columns, viz., **InstanceID** and **RetentionDays**. This file is used by the script to automate the AMI backup process.

I'll explain the above code below:

1. Export `PATH` and set `alias` for aws command.
2. Declare a function `createAMI` which encompasses `create-image`, `decribe-images`, `deregister-image`, etc API calls.
3. With the **instanceList.csv** file, we call the `createAMI` function for each line (or Instance ID) with retention period in days.

Notes:

* The script assumes default AWS CLI profile being used (or role assigned to an instance).
* You can change your input file (**instanceList.csv**) in the script.
* The script has been tested by me and is working on production level.
* It is **highly recommended** to test before using this script.
* I am not responsible for any damage caused by this. (Given that there is no `rm -rf *` command in it.)
___
### Any optimization in the script is welcome.
