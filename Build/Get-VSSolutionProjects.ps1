<#
.Synopsis
Extracts the project-type items from a Visual Studio solution file (.sln)
#>
param(
    [Parameter(Mandatory=$true)] $solution,
    [string]$name, # optional filter parameter
    [string]$type, # optional filter parameter
    [string]$kind  # optional filter parameter
)

$ErrorActionPreference = 'stop';

$projectNodeGuid = '{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}';
$projectItemPattern = 'Project\("([^"]+)"\)\s*=\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"';
$solutionDir = Split-Path $solution;

if($kind -and $kind[0] -ne '{'){
    # Ensure that GUIDS passed on the command line are handled appropriately
    # (PowerShell turns these into strings but doesn't include the {} )
    $kind = "{$kind}";
}

Get-Content $solution | % {
    $line = $_;
    $matches = [System.Text.RegularExpressions.Regex]::Matches($line, $projectItemPattern);
    foreach($match in $matches){
        Write-Verbose $match.Value;
        
        $projectKind = $match.Groups[1].Value;
        $projectType = & {
            switch($projectKind) {
                '{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}' { 'C#'; break; };     
            }
        }
               
        New-Object PSObject -Property:@{
            Name = $match.Groups[2].Value;
            Kind = $projectKind;
            Guid = $match.Groups[4].Value;
            RelPath = $match.Groups[3].Value;
            FullName = (Join-Path $solutionDir ($match.Groups[3].Value));
            Type = $projectType;
        }
    }
} | ? { 
    # Filter output if required
    if($name -and $name -ne $_.Name){
        $false;
    }elseif($type -and $type -ne $_.Type){
        $false;
    }elseif($kind -and $kind -ne $_.Kind){
        $false;    
    }else{
        $true;
    }
}