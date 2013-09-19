param(
    [Parameter(Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Agent.Job] $job, 
    [Parameter(Mandatory=$true)] $stepName,
    [Parameter(Mandatory=$true)] $subSystem,
    [Parameter(Mandatory=$true)] $command,
    $databaseName,
    $proxy,
    $serverName,
    $commandExecutionSuccessCode = 0,
    $successAction = 'GoToNextStep',
    $failureAction = 'QuitWithFailure',
    [switch] $nonFatal,
    [switch] $passThru,
    [scriptblock] $also
)

    write-verbose "Adding job step $jobName.$stepName ($subSystem)"    
    if($command){
        write-verbose $command;
    }

    $step = new-object Microsoft.SqlServer.Management.Smo.Agent.JobStep($job,$stepName);
    $step.SubSystem = $subSystem;
    $step.Command = $command;
    
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
    if($also){
        & $also $step;
    }
    $step.Create();
    # $job.Alter();
    
    if($passThru){
        $step;
    }