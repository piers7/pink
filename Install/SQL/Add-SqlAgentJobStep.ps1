param(
    [Parameter(Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Agent.Job] $job, 
    [Parameter(Mandatory=$true)] $stepName,
    [Parameter(Mandatory=$true)] $subSystem,
    [Parameter(Mandatory=$true)] $command,
    $databaseName,
    $proxy,
    $serverName,
    $commandExecutionSuccessCode = 0,
    [int] $retryAttempts = 0,
    [int] $retryIntervalMins = 0,
    $successAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::GoToNextStep,
    $failureAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithFailure,
    [switch] $nonFatal
)
  
Write-Verbose "[Sql\$sqlInstance\$jobName] Add step '$stepName' ($subSystem)"    
Write-Verbose $command;

$step = new-object Microsoft.SqlServer.Management.Smo.Agent.JobStep($job,$stepName);
$step.SubSystem = $subSystem;
$step.Command = $command;
$step.RetryAttempts = $retryAttempts;
$step.RetryInterval = $retryIntervalMins;
    
switch($subSystem){
    'CmdExec' {
        $step.CommandExecutionSuccessCode = 0;
        break;
    }
}
# appears unneccesary on Sql 2008
# $step.JobStepFlags &= AppendAllCmdExecOutputToJobHistory 
# http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.agent.jobstep.jobstepflags(v=sql.105).aspx

if($proxy){
    $step.ProxyName = $proxy;
}
if($databaseName){
    $step.DatabaseName = $databaseName;
}
if($serverName){
    $step.Server = $serverName;
}
$step.OnSuccessAction = $successAction;
$step.OnFailAction = $failureAction;
$step.Create();