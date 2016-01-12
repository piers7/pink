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
        $manifestPath,
        $outputFolder,
        $version
    )
    # Basic assemble module stages
    $modulePath = .\Assemble-PsModule.ps1 $manifestPath -outputFolder:$outputFolder -version:$version;

    # Load the resulting module (check it basically works)
    # ...and dump what we exported
    $module = Import-Module $modulePath.FullName -PassThru -ErrorAction:Stop;
    Write-Host "Generated module $($module.Name) v$($module.Version)"
    Assert ($module.Version -gt '0.0') "Version not stamped correctly";

    $module | % {
        Write-Host "Module $($_.Name) contains";
        $_.ExportedCommands.Keys | % { "`t$_" };
    }
}

function Assert(
    [Parameter(Mandatory=$true)]
    $condition,
    $failureMessage = '',
    $successMessage
)
{
    if (!$condition) {
        throw "Assert Failed: $failureMessage";
    }elseif($successMessage){
        Write-Host $successMessage -ForegroundColor:Green;
    }
}

Get-Module Pink-* | Remove-Module;
pushd $scriptDir;
try{
    if($version){
        $oldVersion = Get-Content Version.txt;
        $version = .\build\Update-VersionNumber.ps1 $oldVersion -versionNumberPattern:$version;
    }

    # Find (script) module manifests to locate modules and build
    foreach($manifest in Get-ChildItem -Directory -Exclude:output | % { Get-ChildItem $_ *.psd1 -Recurse }){
        AssembleModule $manifest.FullName $outputFolder -version:$version;
        Write-Host
    }
    # AssembleModule .\build $outputFolder -version:$version;
    # AssembleModule .\install\SSAS $outputFolder -version:$version;

    # Smoke test the modules
    Write-Host "Smoke Test Get-VSSolutionProjects";
    $projects = @(Get-VSSolutionProjects -solution:.\Samples\VS2010\SamplesVS2010.sln);
    Assert ($projects.Length -eq 1) -successMessage:Ok;

    #dir $scriptDir *.nuspec -Recurse | .\Scripts\Set-VersionNumber.ps1 -version:$version;
    #$version | Out-File .\Version.txt -Force;

    <#
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
    #>
    if($version){
        Set-Content -Value:$version -Path:Version.txt -Encoding:ASCII;
    }

}catch{
    if($inTeamCity){
        Write-Warning $_;
        if($_.Exception){
            Write-Warning $_.Exception.GetBaseException().Message;
        }
        exit 1;
    }else{
        throw;
    }
}finally{
    popd;
}
