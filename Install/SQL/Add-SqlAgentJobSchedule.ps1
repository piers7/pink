param
(    
    [Parameter(Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Agent.Job] $job, 
    [TimeSpan] $frequency,
    $frequencyType = 'Daily', # Unknown, OneTime, Daily, Weekly, Monthly, MonthlyRelative, AutoStart, OnIdle    [datetime] $startDate = $((Get-Date).Date),
    [timespan] $startTime = '00:00:00',
    [datetime] $endDate = '2099-01-01',
    [timespan] $endTime = '23:59:59',
    [switch] $force
)

if($force){
    $job.RemoveAllJobSchedules();
}
    
$schedule = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobSchedule $job,'Schedule';
$schedule.FrequencyTypes = $frequencyType;
$schedule.FrequencyInterval = 1;
$schedule.FrequencyRecurrenceFactor = 1;

if($frequency -le [timespan]::Zero){
    # Once only
    $schedule.FrequencySubDayTypes = 'Once'; 
    $scheduleName = "Once $($frequencyType)";
}elseif($frequency -lt [TimeSpan]::FromHours(1)){
    # Minutes
    $schedule.FrequencySubDayInterval = $frequency.TotalMinutes;
    $schedule.FrequencySubDayTypes = 'Minute';
    $scheduleName = "Every $($schedule.FrequencySubDayInterval) $($schedule.FrequencySubDayTypes)s";
}else{
    # Assume hours
    $schedule.FrequencySubDayInterval = $frequency.TotalHours;
    $schedule.FrequencySubDayTypes = 'Hour';
    $scheduleName = "Every $($schedule.FrequencySubDayInterval) $($schedule.FrequencySubDayTypes)s";
}

Write-Verbose "[Sql\$sqlInstance\$jobName] Add schedule '$scheduleName' (start $startTime)"    
$schedule.Name = $scheduleName;
$schedule.ActiveStartDate = $startDate.Date;
$schedule.ActiveStartTimeOfDay = $startTime;
$schedule.ActiveEndDate = $endDate.Date;
$schedule.ActiveEndTimeOfDay = $endTime;
$schedule.Create();
