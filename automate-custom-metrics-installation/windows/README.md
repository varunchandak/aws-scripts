# Steps to install Custom Metrics on Windows Instances

### Common Steps
The following steps can be executed in Powershell (much faster):

1. Install aws cli tools for windows (64 Bit):
```sh
Start-Process https://s3.amazonaws.com/aws-cli/AWSCLI64.msi
```

2. Allow scripts to be executed in powershell:
```sh
Set-ExecutionPolicy Unrestricted
```

3. Configure Cloudwatch credentials on the server:
```sh
aws configure --profile cloudwatch
```
4. Enter the required fields carefully.
5. Create scripts directory specific to cloudcover:
```sh
mkdir c:\Scripts\
```
---
## Disk Metrics
1. Download the script `custom-metrics-disk-windows.ps1` from Github to `C:\Scripts` folder.
2. Test the script by running it in powershell (2-3 times):
```sh
&  c:\Scripts\custom-metrics-disk-windows.ps1
```

3. Create a scheduler for script to run on 10 minutes interval:
```sh
schtasks /create /sc minute /mo 10 /tn DiskUsageReport /tr "powershell.exe -WindowStyle Hidden -NoLogo -File c:\Scripts\custom-metrics-disk-windows.ps1"
```
---
### Memory Metrics
1. Download the script `custom-metrics-memory-windows.ps1` from Github to `C:\Scripts` folder.


2. Test the script by running it in powershell (2-3 times):
```sh
&  c:\Scripts\custom-metrics-memory-windows.ps1
```
3. Create a scheduler for script to run for 1 minute:
```powershell
schtasks /create /sc minute /mo 1 /tn MemoryUsageReport /tr "powershell.exe -WindowStyle Hidden -NoLogo -File c:\Scripts\custom-metrics-memory-windows.ps1"
```
---
**NOTES:**
* The script is generic (will run on any windows instance).
* The script `custom-metrics-disk-windows.ps1` covers all disks on a windows instance (no hardcoding needed).
* Instance Role is assumed to be attached with relevant permissions.
