param(
  [Parameter(Mandatory=$true)] $sqlInstance,
  [string] $name
)

$ErrorActionPreference = 'stop';
$scriptDir = split-path $MyInvocation.MyCommand.Path

pushd $scriptDir;
try{
    $server = .\Get-SqlServer $sqlInstance

    if($name){
        # Return the job by name
        $server.JobServer.Jobs[$name];
    }else{
        # Just return all jobs to the pipeline
        # Filter at the caller if you want to do wildcards etc...
        $server.JobServer.Jobs
    }

}finally{
    popd;
}