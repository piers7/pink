param(
    $installPath, 
    $toolsPath, 
    $package, 
    $project
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;
$solutionDir = Split-Path $dte.Solution.Properties.Item('Path').Value;

# For a given version of Visual Studio, which MSBuild should we use?
# Or maybe we should just always use the latest?
$msbuildVersionMap = @{
    '8.0'='2.0.50727';
    '9.0'='3.5';
    '10.0'='4.0.30319';
}

$devEnvVersion = $dte.Version;
$msbuildVersion = $msbuildVersionMap[$devEnvVersion];

pushd $scriptDir;
try{
    $buildSrc = Join-Path $scriptDir '..\SolutionContent\Build.ps1'
    $buildDest = Join-Path $solutionDir 'Build.ps1'
   
    # Only deploy the build.ps1 file if there wasn't one there already
    if(!(Test-Path $buildDest)){
        Get-Content $buildSrc | % { 
            $_ -replace '@DevEnvVersion',$dte.Version `
                -replace '@MsBuildVersion',$msbuildVersion
            ;
        } | Out-File $buildDest -Force;
        
        # $p = .\Get-DTEProject.ps1 'Miscellaneous Files'
        # $p.ProjectItems.AddFromFile($buildDest);
    }

    # Ensure that build file is in the Solution Items (which ensures it gets added to source control)
    # Doesn't matter if it's already there - won't add it twice
    $dte.ItemOperations.AddExistingItem($buildDest);

}finally{
popd;
}