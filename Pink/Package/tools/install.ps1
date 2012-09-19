param(
    $installPath, 
    $toolsPath, 
    $package, 
    $project
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;

pushd $scriptDir;
try{
    .\Publish-BuildArtefacts -project:$project;
}finally{
    popd;
}