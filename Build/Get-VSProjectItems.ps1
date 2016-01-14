<#
.synopsis
Enumerates the items within a Visual Studio project file, and provides their full path

.description
TODO: Not sure why this isn't using Select-Xml
#> 
param(
    [Parameter(Mandatory=$true)] $project,
    [string]$xpath = "//ProjectItem"
)

$ErrorActionPreference = 'stop';

$projXml = new-object system.xml.xmldocument
$projXml.Load($project);
$projectPath = Split-Path $project

$projXml.SelectNodes($xpath) |
    % { 
        $projectItem = $_;
        $fullName = join-path $projectPath $projectItem.Name;
        Add-Member -InputObject:$projectItem -PassThru -Name:FullPath -Value:$fullName -MemberType:NoteProperty -Force;
    }