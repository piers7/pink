[CmdLetBinding()]
param(
    $PackageStoreName = 'LocalNugetPackageStore',
    $version = "#.#.#.+1",
    [switch]$inTeamCity = $(![String]::IsNullOrEmpty($env:TEAMCITY_VERSION))
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;
pushd $scriptDir;
try{
    #if($version){
    #    $version = .\Scripts\Update-VersionNumber.ps1 $version;
    #}

    #dir $scriptDir *.nuspec -Recurse | .\Scripts\Set-VersionNumber.ps1 -version:$version;
    #$version | Out-File .\Version.txt -Force;

    $outDir = Join-Path ([IO.Path]::GetPathRoot($scriptDir)) $packageStoreName;
    if(!(Test-Path $outDir)){
        $void = mkdir $outDir;
    }
    Write-Verbose "Packaging Package\Pink.nuspec to $outDir"
    nuget.exe pack Package\Pink.nuspec -outputdirectory $outDir

    if(!$?){ 
        Write-Error "Nuget.exe failed with $LASTEXITCODE"
        exit $LASTEXITCODE 
    }

    $msbuild = .\Scripts\Get-MsBuildPath.ps1
    dir $scriptDir\Samples *.sln -Recurse | % { 
        & $msbuild $_.FullName;
        if(!$?){ 
            Write-Error "msbuild.exe failed with $LASTEXITCODE"
            exit $LASTEXITCODE 
        }
    }

}catch{
    if($inTeamCity){
        Write-Warning $_;
        if($_.Exception){
            write-warning $_.Exception.GetBaseException().Message;
        }
        exit 1;
    }
}finally{
    popd;
}
