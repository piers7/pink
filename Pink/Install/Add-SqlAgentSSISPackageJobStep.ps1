param(
    [Parameter(Mandatory=$true)] [Microsoft.SqlServer.Management.Smo.Agent.Job] $job, 
    [Parameter(Mandatory=$true)] $stepName,
    [Parameter(Mandatory=$true)] $package,
    $proxy,
    [hashtable] $connections,
    [hashtable] $variables = @{},
    $successAction = 'GoToNextStep',
    $failureAction = 'QuitWithFailure',
    [switch] $nonFatal,
    [switch] $passThru,
    [switch] $force32Bit,
    [scriptblock] $also
)

    $ErrorActionPreference = 'stop';
    $scriptDir = split-path $MyInvocation.MyCommand.Path

    $sqlServer = $job.Parent.Parent;
    $sqlArchitecture = $sqlServer.Platform;
    $sqlVersionMajor = $sqlServer.VersionMajor;
    
    #$programFilesDir = '%ProgramFiles%';
    $programFilesDir = 'C:\Program Files';

    if($force32Bit -and ($sqlArchitecture -match 'x64')){
        # Force to use 32 bit program files directory for SSIS etc...
        # SQL Agent doesn't appear to support environment expansion in the leftmost part of the command
        # $programFilesDir = '%ProgramFiles(x86)%';
        $programFilesDir = 'C:\Program Files (x86)';
    }
        
    $dtExec = "`"{0}\Microsoft SQL Server\{1}0\DTS\BINN\dtexec`"" -f $programFilesDir,$sqlVersionMajor

    $commandBuilder = new-object System.Text.StringBuilder
    [void] $commandBuilder.Append("$dtExec /sql `"$package`" /server $($sqlServer.Name)");
    foreach($item in $connections.GetEnumerator()){
        [void] $commandBuilder.AppendFormat(' /CONNECTION "{0}";"{1}"', ($item.Key,$item.Value));
    }
    foreach($item in $variables.GetEnumerator()){
        [void] $commandBuilder.AppendFormat(' /SET \package.Variables["{0}"].Value;"{1}"', ($item.Key,$item.Value));
    }

    $command = $commandBuilder.ToString()
    
    pushd $scriptDir;
    try{
        .\Add-SqlAgentJobStep -job:$job -stepName:$stepName -subSystem:CmdExec -proxy:$proxy -command:$command -successAction:$successAction -failureAction:$failureAction -passThru:$passThru -also:$also;
    }finally{
    popd;
    }
