param(
    [Parameter(Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Agent.Job] $job, 
    [Parameter(Mandatory=$true)] $scheduleName,
    [Parameter(Mandatory=$true)] $frequencyMins,
    $frequencyTypes = 'Daily',
    $frequencyInterval = 1,
    [datetime] $startDate = $((Get-Date).Date),
    [timespan] $startTime = '00:00:00',
    [datetime] $endDate = '2099-01-01',
    [timespan] $endTime = '23:59:59',
    [switch] $force
)

    if($force){
        $job.RemoveAllJobSchedules();
    }
    
    $schedule = new-object Microsoft.SqlServer.Management.Smo.Agent.JobSchedule $job,$scheduleName
    $schedule.FrequencyTypes = $frequencyTypes;
    $schedule.FrequencyInterval = $frequencyInterval;
    $schedule.FrequencyRecurrenceFactor = 1;
    if($frequencyMins -gt 0){
        $schedule.FrequencySubDayInterval = $frequencyMins;
        $schedule.FrequencySubDayTypes = 'Minute';
    }else{
        $schedule.FrequencySubDayTypes = 'Once'; 
    }
    $schedule.ActiveStartDate = $startDate.Date;
    $schedule.ActiveStartTimeOfDay = $startTime;
    $schedule.ActiveEndDate = $endDate.Date;
    $schedule.ActiveEndTimeOfDay = $endTime;
    $schedule.Create();
