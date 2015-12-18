<#
.Synopsis
Locates the path to MSBuild, given a framework version (or uses the highest installed)

.Notes
As per VS 2013, MSBuild is be bundled with Visual Studio, not the .Net Framework.
See http://blogs.msdn.com/b/visualstudio/archive/2013/07/24/msbuild-is-now-part-of-visual-studio.aspx
However the ToolLocationHelper class (to find it) has *also* moved into VS2013
https://msdn.microsoft.com/en-us/library/microsoft.build.utilities.toollocationhelper(v=vs.121).aspx
... so bit of a chicken-and-egg issue

#>
[CmdLetBinding()]
param(
    # Specify the framework version, or leave blank default to highest located
    $frameworkVersion, 

    # Force using 32 bit version of MSBuild
    [switch] $x86
)

# very simple implementation that just uses embedded version numbers
function NumericalSort(){
    $input | ? { $_ -match '^v(\d+(\.\d+))?' } | % { 
        New-Object -TypeName:PSObject -Property:@{
            SortKey = $Matches[1] -as [Float];
            Value = $_
        }
    } | Sort SortKey | Select-Object -ExpandProperty:Value
}

# Resolve framework directory (for MsBuild)
$frameworkKey = Get-Item "hklm:\software\microsoft\.netframework"
$frameworkDir = $frameworkKey.GetValue('InstallRoot');
if(!$frameworkVersion){
    $frameworkVersion = ($frameworkKey.GetSubKeyNames() | NumericalSort | Select-Object -Last:1).Substring(1);
}
if($x86){
    $frameworkDir = $frameworkDir -replace 'Framework64','Framework';
}
$msbuild = Resolve-Path "$frameworkDir\v$frameworkVersion\MSBuild.exe";

Write-Verbose "Using MsBuild from $msbuild";
$msbuild;