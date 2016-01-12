<#
.synopsis
Packs a SSRS project using xcopy / Octopus Deploy conventions
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
    $nuspec,
    [switch] $forceUseConventions
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
    $propertiesString = '';
    if($properties){
        $propertiesString = ($properties.GetEnumerator() | % { '{0}={1}' -f $_.Key,$_.Value }) -join ';'
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

$projectDir = Split-Path $projectPath;
$projectName = [IO.Path]::GetFileNameWithoutExtension($projectPath);
$nugetProperties = @{
    id = $projectName;
    description = 'SSRS project'
};

Write-Host "Packing SSRS project '$projectName'";
Write-Host "... Using $nuspec";

$specXml = New-Object System.Xml.XmlDocument
$specXml.Load($nuspec)
$files = $specXml.SelectSingleNode("//files");

if($files -and !$forceUseConventions){
    # just pack what's there
    $baseDir = Split-Path $nuspec;
    nuget-pack $nuspec $outputDir $semVer $projectDir;
    return;
}elseif($files){
    Write-Host "... Content conventions will be applied, existing FILES element will be ignored"
    $files.ParentNode.RemoveChild($files);
}else{
    Write-Host "... Content conventions will be applied - nuspec lists no files"
}
$files = $specXml.DocumentElement.AppendChild($specXml.CreateElement('files'));

# Create files element and populate from project 'Content' items
Select-Xml -Path:$projectPath -XPath:'//*[self::ProjectItem or self::ProjectResourceItem]' |
    Select-Object -ExpandProperty:Node |
    % {
        $contentSrc = $_.FullPath;
        $target = ".\" + (Split-Path $contentSrc);
        Write-Verbose "Adding content file $contentSrc"
        [void]( Add-ChildElement $files 'file' @{ src=$contentSrc; target=$target } )
    }

$tempSpec = [io.Path]::ChangeExtension($nuspec, '.generated.nuspec');
$specXml.Save($tempSpec);

nuget-pack $tempSpec $outputDir $semVer $projectDir -properties:$nugetProperties;