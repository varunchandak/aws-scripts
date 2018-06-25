# AMI Backups and Retention using AWS Lambda

---
#### NOTE: AMI and Instance Names and Name Tags must be between 3 and 128 characters long, and may contain letters, numbers, '(', ')', '.', '-', '/' and '_' only. Not following this nomenclature will lead to failure of the lambda function.
---

Here, we are using 2 AWS Lambda functions viz., **createAMI** and **deleteAMI**, which will create AMIs and delete AMIs, respectively. Both these functions are explained in detail below. **<u>Please note that both the lambda functions cover all the regions.</u>**

## createAMI

**Table of details:**

| Name                        | Value             |
| --------------------------- | ----------------- |
| Name of the Lambda Function | createAMI         |
| Timeout                     | 5 min             |
| Role Permissions            | `ec2:*`           |
| Runtime                     | `python2.7`       |
| File Name                   | `createAMI.py`    |
| Schedule                    | `rate(5 minutes)` |

**Documentation:**

The lambda function make use of tags on EC2 intances which provides all the information required to create an AMI. The table below explains the tags required.

| Tag Name  | Format       | Default Value |
| --------- | ------------ | ------------- |
| AMIBackup | Yes/No       | No            |
| AMITime   | HH:MM        | 15:00         |
| Reboot    | Yes/No       | No            |
| Retention | Whole Number | 7             |

In the above table:

- `AMIBackup`: It is used to specify which Instance has to be backed up.
- `AMITime`: It is used to specify the time when the AMI has to be created.
- `Reboot`: It is used to specify if the instance has to be rebooted when creating the AMI.
- `Retention`: It is used to specify the AMI retention period in **days**.

---

## deleteAMI

**Table of details:**

| Name                        | Value                 |
| --------------------------- | --------------------- |
| Name of the Lambda Function | deleteAMI             |
| Timeout                     | 5 min                 |
| Role Permissions            | `ec2:*`               |
| Runtime                     | `python2.7`           |
| File Name                   | `deleteAMI.py`        |
| Schedule                    | `cron(00 15 * * ? *)` |

**Documentation:**

The lambda function make use of tags on EC2 intances which provides all the information required to delete an AMI. The tags are copied from the instance to AMI via **createAMI** function. The table below explains the tags required.

| Tag Name  | Format       | Default Value        |
| --------- | ------------ | -------------------- |
| AMIBackup | Yes/No       | Copied from Instance |
| AMITime   | HH:MM        | Copied from Instance |
| Reboot    | Yes/No       | Copied from Instance |
| Retention | Whole Number | Copied from Instance |

In the above table(s):

* `AMIBackup`: It is used to specify which Instance has to be backed up. **deleteAMI** will only get triggered if this tag is present with `Yes` value.
* `AMITime`: It is used to specify the time when the AMI has to be created.
* `Reboot`: It is used to specify if the instance has to be rebooted when creating the AMI.
* `Retention`: It is used to specify the AMI retention period in **days**.
