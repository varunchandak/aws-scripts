# Steps to install Custom Metrics on Linux Instances

1. Access the root account

    ```sh
    sudo -i
    ```

2. Create a directory specific to **scripts**

    ```sh
    mkdir -p /home/scripts
    ```

3. Configure AWS credentials for cloudwatch:

    ```sh
    aws configure --profile cloudwatch
    ```

4. Edit the script to add **aws profile**

5. Run the script manually for few times:

    ```sh
    bash -x <script_name>.sh DiskMetric
    ```

6. If the script gives error like: **bc: not found**, then

    ```
    yum install bc -y
    ```

    or

    ```
    apt-get install bc -y
    ```

7. Steps to set cronjob/scheduler:

    ```
    * * * * * 	/bin/bash /home/scripts/<script_name>.sh DiskMetric
    * * * * * 	/bin/bash /home/scripts/<script_name>.sh MemoryMetric
    ```

    Save and Exit the cron.

8. Once you finish with everything set the alarms on the dashboard for the same.
---

## Scripts Description
* `auto-install-custom-metrics-linux.sh`: This script contains automated process to install `custom-metrics-disk-memory-linux.sh` script, with respective cronjobs and package installations.
* `custom-metrics-auto-install-url.sh`: This script contains the wget command to download the `auto-install-custom-metrics-linux.sh` script.
* `custom-metrics-disk-memory-linux.sh`: This script contains the `PutMetricData` function to send metrics to CloudWatch DashBoard.

## NOTES:

* The script is generic (will run on any Linux instance)
* This script will include all the disks and mount points in the linux system.
* The same script will take argument `MemoryMetric` and `DiskMetric`.
* The `auto-install-custom-metrics-linux.sh` script will implement all the steps above, *automatically*.
