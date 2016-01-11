<#
.synopsis
Allows a Visual Studio Project to be packed using xcopy / Octopus Deploy conventions
It's easier to use OctoPack, but that doesn't support many BI project types
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
    $nuspec
)

$ErrorActionPreference = 'stop';


function Add-ChildElement($parent, $name, [hashtable]$attributes){
    $child = $parent.OwnerDocument.CreateElement($name);
    foreach($item in $attributes.GetEnumerator()){
        $child.SetAttribute($item.Key, $item.Value);
    }
    $parent.AppendChild($child);
}

# .synopsis
# Packs a website using xcopy / Octopus Deploy conventions
# For this we re-write the spec file on the fly to include project Content
# if the Files element doesn't already exist
function Pack-Website($projectPath, $nuspec, [switch] $forceUseConventions, [switch] $ignoreWebTransforms){
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
}

function Pack-ProjectDefault($projectPath, $nuspec){
    # Default behaviour is to just pack the spec as-is
    Write-Host "Packing $(Split-Path -Leaf $projectPath) as default";
    $baseDir = Split-Path $nuspec;

    nuget-pack $nuspec $outputDir $semVer $baseDir;
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

$projectDir = Split-Path $projectPath;
if(Test-Path "$projectDir\web.config"){
    Pack-Website $projectPath $nuspec;
}else{
    Pack-ProjectDefault $projectPath $nuspec;
}