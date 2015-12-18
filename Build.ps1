[CmdLetBinding()]
param(
    $PackageStoreName = 'LocalNugetPackageStore',
    $version = "#.#.#.+1",
    $outputFolder = ".\output",
    [switch]$inTeamCity = $(![String]::IsNullOrEmpty($env:TEAMCITY_VERSION))
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path (Convert-Path $MyInvocation.MyCommand.Path);

function AssembleModule{
    param(
        $moduleFolder,
        $outputFolder
    )
    # Basic assemble module stages
    $moduleFile = .\Assemble-PsModule.ps1 $moduleFolder -outputFolder:$outputFolder;
    $module = Import-Module $moduleFile.FullName -PassThru #-ErrorAction:stop;

    # Dump out what modules we built
    $module | % {
        Write-Host "Module $($_.Name) contains";
        $_.ExportedCommands.Keys | % { "`t$_" };
    }
}

pushd $scriptDir;
try{
    Get-Module Pink-* | Remove-Module;

    AssembleModule .\build $outputFolder;
    AssembleModule .\install\SSAS $outputFolder;

    # Smoke test the modules
    Write-Host "Smoke Test Get-VSSolutionProjects";
    Get-VSSolutionProjects -solution:.\Samples\VS2010\SamplesVS2010.sln;

    return;
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
    }else{
        throw;
    }
}finally{
    popd;
}
