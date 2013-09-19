<#
.Synopsis
Builds the solution(s), and provides a starting-point for customisation

.Remarks
If modified, this file will not be redacted if you uninstall the Pink Nuget package
#>
param(
    $buildConfig = 'debug',
    $platform = 'Any CPU',

    $frameworkVersion = '@MsBuildVersion',
    $devEnvVersion = '@DevEnvVersion',
    [switch] $x86 = $true, # on 64 bit machines, use 32 bit MSBuild
    [switch] $useDevEnv
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;

# Create programfiles32 variable for x86 only apps
$programFiles32 = $env:ProgramFiles
if (test-path environment::"ProgramFiles(x86)") { $programFiles32 = (gi "Env:ProgramFiles(x86)").Value };

# Resolve framework directory (for MsBuild)
$frameworkDir = (Get-ItemProperty "hklm:\software\microsoft\.netframework").InstallRoot;
if($x86){
    $frameworkDir = $frameworkDir -replace 'Framework64','Framework';
}
$msbuild = Resolve-Path "$frameworkDir\v$frameworkVersion\MSBuild.exe";

# Resolve Visual Studio path (for DevEnv.com)
# NB: Don't resolve-path here, as might not be used (and therefore need not be installed)
$devEnv = "$programFiles32\Microsoft Visual Studio $devEnvVersion\Common7\Ide\DevEnv.com";

function ExecProcess([string]$command,[string[]]$cmdArgs){
    $p = Start-Process -FilePath:$command -ArgumentList:$cmdArgs -LoadUserProfile:$false -NoNewWindow -PassThru -Wait;
    if($p.ExitCode -gt 0){
        throw "$command failed: exitcode $($p.ExitCode)";
    }
}

function Exec([scriptblock]$command){
    & $command;
    if(-not $?){
        throw "$command failed: exitcode $LastExitCode";
    }
}

pushd $scriptDir;
try{
    foreach($sln in (dir $scriptDir *.sln)){
        if($useDevEnv){
            & $devenv $sln /build;           
        }else{
            & $msbuild $sln;
        }
        if(-not $?){
            throw "$sln failed: exitcode $LastExitCode";
        }
    }
}finally{
    popd;
}