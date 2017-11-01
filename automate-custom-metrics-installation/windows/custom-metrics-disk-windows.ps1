function ToArray
{
  begin
  {
    $output = @();
  }
  process
  {
    $output += $_;
  }
  end
  {
    return ,$output;
  }
}

$disklist=Get-WmiObject -Class Win32_LogicalDisk | Select-Object -Property DeviceID, @{Name='UsedPercent';Expression={(100-($_.FreeSpace/$_.Size)*100)}} |ToArray

for ($j=0;$j -lt $disklist.Count ; $j++)
{
aws cloudwatch put-metric-data --namespace "Windows/Disk" --metric-name DiskUtilization --unit Percent --value $disklist[$j].UsedPercent --dimensions "InstanceId=$((Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id).Content),Drive=$($disklist[$j].DeviceID)"
}
