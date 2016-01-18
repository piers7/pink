[CmdLetBinding()]
param(
    $PackageStoreName = 'LocalNugetPackageStore',
    $version = "#.#.#.+1",
    $outputDir = ".\output",
    $nugetExe = '.nuget\nuget.exe',
	[scriptblock] $versionNumberCallback
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path (Convert-Path $MyInvocation.MyCommand.Path);

function AssembleModule{
    param(
        $manifestPath,
        $outputDir,
        $version
    )
    # Basic assemble module stages
    $modulePath = .\Assemble-PsModule.ps1 $manifestPath -outputDir:$outputDir -version:$version;

    # Load the resulting module (check it basically works)
    # ...and dump what we exported
    $module = Import-Module $modulePath.FullName -PassThru -ErrorAction:Stop;
    Write-Host "Generated module $($module.Name) v$($module.Version)"
    Assert ($module.Version -gt '0.0') "Version not stamped correctly";

    $module | % {
        Write-Host "Module $($_.Name) contains";
        $_.ExportedCommands.Keys | % { 
            $commandName = $_;
            $help = Get-Help $commandName;
            $description = if ($help.synopsis -and $help.synopsis[0] -ne "`r") { $help.synopsis} else { "" };
            "`t{0} ({1})" -f $commandName,$description; 
        };
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

function Write-Header(){
    Write-Host
    Write-Host $args -ForegroundColor:Cyan
    Write-Host ********
}

# Check we have nuget.exe, if not download
if(!(Test-Path $nugetExe)){
    Write-Heade "Downloading nuget.exe..."
    $nugetDir = Split-Path -Parent $nugetExe;
    if(!(Test-Path $nugetDir)){
        [void] (mkdir $nugetDir);
    }
    Write-Host "Downloading nuget.exe..."
    $client = new-object net.webclient
    $client.DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', $nugetExe);
}
$nugetExe = (Resolve-Path $nugetExe).Path;

Get-Module Pink-* | Remove-Module;
pushd $scriptDir;
try{
    # Clear down the output directory first
    if(Test-Path $outputDir){
        Remove-Item $outputDir -Recurse;
    }

    if($version){
        $oldVersion = Get-Content Version.txt;
        $version = .\build\Update-VersionNumber.ps1 $oldVersion -versionNumberPattern:$version;
        if($versionNumberCallback){ & $versionNumberCallback $version; }
    }

    Write-Header "Building pink v$version";
    # Find (script) module manifests to locate modules and build
    foreach($manifest in Get-ChildItem -Directory -Exclude:output | % { Get-ChildItem $_ *.psd1 -Recurse }){
        AssembleModule $manifest.FullName $outputDir -version:$version;
        Write-Host
    }

    # Smoke test the modules
    Write-Header Smoke tests
    Write-Host "Smoke Test Get-VSSolutionProjects";
    $projects = @(Get-VSSolutionProjects -solution:.\Samples\VS2010\SamplesVS2010.sln);
    Assert ($projects.Length -eq 1) -successMessage:Ok;

    # Package up everything into nuget
    Write-Header Packing
    Write-Host "Packaging Package\Pink.nuspec to $outDir"
    & $nugetexe pack Package\Pink.nuspec -outputdirectory $outputDir -version $version;
    if(!$?){ 
        Write-Error "Nuget.exe failed with $LASTEXITCODE"
        exit $LASTEXITCODE 
    }

    if($version){
        Set-Content -Value:$version -Path:Version.txt -Encoding:ASCII -Force;
    }

}finally{
    popd;
}
