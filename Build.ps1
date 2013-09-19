[CmdLetBinding()]
param(
    $PackageStoreName = 'LocalNugetPackageStore',
    [switch]$updateVersion
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;
pushd $scriptDir;
try{

$version = Get-Content Version.txt;
if($updateVersion){
    $version = .\Scripts\Update-VersionNumber.ps1 $version;
}
dir $scriptDir *.nuspec -Recurse | .\Scripts\Set-VersionNumber.ps1 -version:$version;
$version | Out-File .\Version.txt -Force;

$outDir = Join-Path ([IO.Path]::GetPathRoot($scriptDir)) $packageStoreName;
if(!(Test-Path $outDir)){
    $void = mkdir $outDir;
}
nuget.exe pack Package\Pink.nuspec -outputdirectory $outDir

$msbuild = .\Scripts\Get-MsBuildPath.ps1
dir $scriptDir\Samples *.sln -Recurse | % { 
    & $msbuild $_.FullName;
}

}finally{
popd;
}