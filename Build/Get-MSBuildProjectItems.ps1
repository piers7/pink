# .synopsis
# Returns a list of the files within a MSBuild project file, by content type
param(
    [Parameter(Mandatory=$true)] $project,

    # Types of file to return: None, Compile, Content etc... 
    $type = 'Compile'
)

$ErrorActionPreference = 'stop';
$project = (resolve-path $project).Path;
$projectDir = Split-Path $project -Parent;
$ns = @{
    msb = 'http://schemas.microsoft.com/developer/msbuild/2003';
}

Select-Xml -Path:$project -XPath:"//msb:$type" -Namespace:$ns |
    Select-Object -ExpandProperty:Node | 
    % {
        New-Object psobject -Property:@{
            RelPath = $_.Include;
            Directory = (Split-Path -Parent $_.Include);
            FullName = Join-Path $projectDir $_.Include;
        }
    }
