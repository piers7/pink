<#
.synopsis
Packs a Visual Studio Web Site project to a xcopy / Octopus Deploy style nuget.

.description
If <files> element present in nuspec is missing (or -forceUseConventions is passed)
then conventions are used to add all project Content to the nuget.
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    $projectPath,
    [Parameter(Mandatory=$true)]
    $outputDir,
    [Parameter(Mandatory=$true)]
    $semVer,

    $nugetExe = '..\.nuget\nuget.exe',

    # Path to the nuspec if not in default location (next to project file)
    $nuspec,

    # Forces ignoring existing content in nuspec, and using conventions from project file instead
    [switch]$forceUseConventions,
    # If set, web config transform files are excluded
    [switch]$ignoreWebTransforms
)

$ErrorActionPreference = 'stop';


function Add-ChildElement($parent, $name, [hashtable]$attributes){
    $child = $parent.OwnerDocument.CreateElement($name);
    foreach($item in $attributes.GetEnumerator()){
        $child.SetAttribute($item.Key, $item.Value);
    }
    $parent.AppendChild($child);
}

function nuget-pack($nuspec, $outputDir, $semVer, $baseDir, [hashtable]$properties){
    if($properties){
        $propertiesString = ($properties.GetEnumerator() | % { '{0}={1}' -f $_.Key,$_.Value }) -join ';'
    }else{
        $propertiesString = "Foo=Bar"
    }
    & $nugetexe pack $nuspec -o $outputDir -Version $semVer -basePath $baseDir -NoPackageAnalysis -NonInteractive -Properties $propertiesString
    if($LASTEXITCODE -gt 0){
        throw "Failed with exit code $LASTEXITCODE";
    }
}


$outputDir = (Resolve-Path $outputDir).Path;
$projectPath = (Resolve-Path $projectPath).Path;
$nugetExe = (Resolve-Path $nugetExe).Path;

if(-not $nuspec){
    $nuspec = [io.path]::ChangeExtension($projectPath, '.nuspec');
    Write-Verbose "Inferring nuget spec through convention at '$nuspec'"
}else{
    $nuspec = (Resolve-Path $nuspec).Path;
}

$projectName = $(Split-Path -Leaf $projectPath);
$projectDir = Split-Path $projectPath;

Write-Host "Packing $projectName as Website";
$specXml = New-Object System.Xml.XmlDocument
$specXml.Load($nuspec)
$files = $specXml.SelectSingleNode("//files");

if($files -and !$forceUseConventions){
    # just pack what's there
    nuget-pack $nuspec $outputDir $semVer $projectDir;
    return;
}elseif($files){
    $files.ParentNode.RemoveChild($files);
}

# Create files element and populate from project 'Content' items
Write-Verbose "Using project-content based convention for $projectName"
$files = $specXml.DocumentElement.AppendChild($specXml.CreateElement('files'));
$ns = @{
    msb = 'http://schemas.microsoft.com/developer/msbuild/2003';
}
Select-Xml -Path:$projectPath -XPath:'//msb:Content' -Namespace:$ns | 
    % {
        $contentSrc = $_.Node.GetAttribute('Include');
        $target = ".\" + (Split-Path $contentSrc);
        Write-Verbose "Adding content file $contentSrc"
        [void]( Add-ChildElement $files 'file' @{ src=$contentSrc; target=$target } )
    }

[void]( Add-ChildElement $files 'file' @{ src="bin\**\*"; target=".\bin" } )
if(!$ignoreWebTransforms){
    [void]( Add-ChildElement $files 'file' @{ src="Web.*.config"; target=".\" } )
}

$tempSpec = [io.Path]::ChangeExtension($nuspec, '.generated.nuspec');
$specXml.Save($tempSpec);

nuget-pack $tempSpec $outputDir $semVer $projectDir;