# Script to set slack alarm actions for cloudwatch alarms with 90% thresholds
---
This script will set slack SNS arn as alarm action to those cloudwatch alarms whose thresholds are `> 90%`

Notes:
* This uses `awless`. Make sure to install and configure `awless` properly.
* This script will recursively check `ALL` the alarms and set on it. This can be optimized for alarms which do not have slack alerts configured.
