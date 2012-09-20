<#
.Synopsis
Creates a new (empty) SQL Server Agent Job, or overwrites an existing one
#>
param(
    [Parameter(Mandatory=$true)] $sqlInstance, 
    [Parameter(Mandatory=$true)] $jobName,
    $category = '[Uncategorized (Local)]',
    $description,
    [switch] $disabled
)

$ErrorActionPreference = 'stop';
$scriptDir = split-path $MyInvocation.MyCommand.Path

write-host "Creating job $jobName (on $sqlInstance)";
pushd $scriptDir;
try{
    $server = .\Get-SqlServer $sqlInstance;
}finally{
    popd;
}
$agent = $server.JobServer;
$job = $agent.Jobs[$jobName];
if($job){
    $job.IsEnabled = !$disabled;
    $job.RemoveAllJobSteps();
    $job.RemoveAllJobSchedules();
    $job.Alter();
}else{
    $categoryObj = $agent.JobCategories[$category];
    $job = new-object Microsoft.SqlServer.Management.Smo.Agent.Job($server.JobServer, $jobName, $categoryObj.ID);
    $job.Description = $description;
    $job.IsEnabled = !$disabled;
    $job.Create();
    $job.ApplyToTargetServer("(local)");
}

$job;