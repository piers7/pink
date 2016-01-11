param(
    [Parameter(Mandatory=$true)] $manifestPath,
    $outputFolder = '.\output',
    $modulePrefix,
    $version,
    [switch]$noExports
)

$scriptDir = Split-Path (Convert-Path $MyInvocation.MyCommand.Path);

if(!(Test-Path $outputFolder)){
    [void] (mkdir $outputFolder);
}
[void] (Resolve-Path $manifestPath);

$manifestDirectory = Split-Path $manifestPath;
$moduleName = [IO.Path]::GetFileNameWithoutExtension($manifestPath);
$modulePath = Join-Path $outputFolder "$moduleName.psm1"
if($modulePrefix){
    $modulePrefix = $moduleName -split '-' | Select-Object -Last:1;
}

$manifestTargetPath = Join-Path $outputFolder (Split-Path -Leaf $manifestPath);

Write-Host "Assembling $modulePath"
"" | Set-Content $modulePath

# Include the manifest (with updated version number if required)
Copy-Item $manifestPath $outputFolder -Force;
if($version){
    Get-Item $manifestTargetPath | & $scriptDir\build\Set-VersionNumber.ps1 $version
}

# Now assemble the module contents
dir $manifestDirectory *.ps1 | 
    ? { !$_.Name.StartsWith('_') } |
    % { 
        $file = $_;
        Write-Verbose "Including $file"
        Get-Content $file.FullName | & {
            begin {
                $functionName = $_.BaseName; # file name without extension
                $wroteHeader = $false;
                "# begin $file"
            }
            process {
                $line = $_;
                if($line.Contains('= Split-Path $MyInvocation.MyCommand.Path') -or $line.Contains('= Split-Path (Convert-Path $MyInvocation.MyCommand.Path)')){
                    throw "$functionName - Can''t use MyInvocation.MyCommand.Path in a script module (use an if(`$PSScriptRoot){}else{} block instead)";
                }

                if(!$wroteHeader -and (($line -match '\s*param\s*\(') -or ($line -match '\[CmdLetBinding'))){
                    "function $functionName {"
                    $wroteHeader = $true;
                }else{
                    # Attempt to re-point inter-script references to functions within the module
                    $internalCallPattern = ('\.\\(\w+\-{0}\w+)\.ps1' -f $modulePrefix);
                    $line = $line -replace $internalCallPattern,'$1';
                }
                if($line -match 'Export\-ModuleMember'){
                    $noExports = $true;
                }

                # always emit original line (under current structure anyways)
                $line;
            }
            end{
                "";
                if($wroteHeader){
                    "} # end $functionName";
                    if(!$noExports){
                        "Export-ModuleMember -function $functionName;"
                    }
                }else{
                    "# end $file"
                }
                "";
                "";
            }
        } | Out-File -Append -FilePath:$modulePath -Encoding:ASCII;
    }

# return the FileInfo back to the caller *of the manifest*
# otherwise Manifest information is not loaded
# nb: manifest *must* point back to the script module
Get-Item $manifestTargetPath;