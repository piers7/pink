<#
.synopsis
Very simple starter psake build script

Parameters required:
    $solutionPath - relative path to solution
    $version
    $semVer
#>
properties {
    $buildConfig = 'Debug';
    $buildLogging = 'Minimal';

    $outputDir = "..\bin";

    $inTeamCity = (![String]::IsNullOrEmpty($env:TEAMCITY_VERSION));
}

# *****************
# Basic entry points
# *****************

task default -depends:Build;

task CI -depends:Clean,UpdateVersionNumber,Build,QuickTest,Pack;

task Full -depends:Clean,UpdateVersionNumber,Build,Test,Pack;

# *****************
# Support functions
# *****************

function Resolve-PathRelativeTo($path, $relativeTo){
    pushd $relativeTo;
    try{
        (Resolve-Path $path).Path;
    }finally{
        popd;
    }
}


# *****************
# Tasks
# *****************

task PackageRestore {
    exec {
        ..\.nuget\nuget.exe Restore $solutionPath;
    }
}


task Clean {
	if(Test-Path $outputDir){
		Remove-Item $outputDir -Force -Recurse;
	}
}

task OutputFolderPresent {
    if(-not (Test-Path $outputDir)){
         mkdir $outputDir | Out-Null;
    }
}

task UpdateVersionNumber -requiredVariables:version,semVer {
    # Because the TeamCity AssemblyInfoPatcher is an all-or-nothing affair - can't just overwrite *parts* of the version number
    Get-Item ..\AssemblyCommonInfo.cs | .\Set-VersionNumber.ps1 -version:$version -informationalVersion:$semVer -force;
}

task Build -depends:OutputFolderPresent -requiredVariables:solutionPath {
    exec {
        msbuild $solutionPath /target:Rebuild /p:"Configuration=$buildConfig" /v:$buildLogging;
    }
}

task QuickTest {
	# Normally unit tests go in here
}

task Test -depends:QuickTest {
	# Normally integration tests and the like go in here
}

task Pack -depends:OutputFolderPresent,Build -requiredVariables:solutionPath,semVer {
    $solutionDir = Split-Path $solutionPath;
    # $projectFolders = dir $solutionDir -Exclude:Packages,Lib,Build,Bin, | ? { $_.PSIsContainer };

    # Our aging internal nuget server can't (at present) cope with tags present in the octopack nuget
    # Also, OctoPack doesn't cater for many BI project types
    # So I've kinda rolled my own
    foreach($project in .\Get-VSSolutionProjects.ps1 -solution:$solutionPath -kind:"{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}"){ # C# projects only (less noise)
        $projectFolder = Split-Path $project.FullName;
        $spec = Get-ChildItem -Path:$projectFolder -Filter:*.nuspec | Select-Object -First:1;
        if($spec){ 
            .\Pack-VSProject.ps1 $solutionDir $project.FullName $outputDir $semVer $spec.FullName;
        }
    }
}