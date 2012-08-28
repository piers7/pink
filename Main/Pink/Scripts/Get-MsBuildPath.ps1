<#
.Synopsis
Locates the path to MSBuild, given a framework version (or uses the highest installed)
#>
param(
    $frameworkVersion, # left blank, defaults to highest located
    [switch] $x86      # force locating 32 bit version of MSBuild
)

# Resolve framework directory (for MsBuild)
$frameworkKey = Get-Item "hklm:\software\microsoft\.netframework"
$frameworkDir = $frameworkKey.GetValue('InstallRoot');
if(!$frameworkVersion){
    $frameworkVersion = ($frameworkKey.GetSubKeyNames() | ? { $_ -match '^v\d' } | Select-Object -Last:1).Substring(1);
}
if($x86){
    $frameworkDir = $frameworkDir -replace 'Framework64','Framework';
}
$msbuild = Resolve-Path "$frameworkDir\v$frameworkVersion\MSBuild.exe";

Write-Verbose "Using MsBuild from $msbuild";
$msbuild;