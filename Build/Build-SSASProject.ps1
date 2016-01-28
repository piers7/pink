<#
.Synopsis
Builds a .dwproj into an .asdatabase

.Description
Builds a Visual Studio / BIDS Analysis Services project into a .asdatabase file,
as would happen in devenv during build time.

Based on SSASHelper code lifted from Analysis Services project on codeplex
http://sqlsrvanalysissrvcs.codeplex.com/SourceControl/latest#SsasHelper/SsasHelper/ProjectHelper.cs
Thanks DDarden - I was hoping it was wasn't that hard
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    $projectPath,
    # [Parameter(Mandatory=$true)]
    $outputDir,
    $version = '11.0.0.0'
)

$ErrorActionPreference = 'stop';
try{
    Add-Type -AssemblyName:"Microsoft.AnalysisServices, Version=$version, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction:Stop;
}catch{
    Write-Warning "Failed to load SSAS assemblies - is AMO installed?"
    throw;
}

$ns = @{
    AS = 'http://schemas.microsoft.com/analysisservices/2003/engine';
}

$database = New-Object Microsoft.AnalysisServices.Database
$projectPath = (Resolve-Path $projectPath).Path;
$projectDir = Split-Path $projectPath -Parent;
$projectName = [IO.Path]::GetFileNameWithoutExtension($projectPath);
if(!$outputDir){
    $outputDir = Join-Path $projectDir 'bin';
}

Write-Host "Building $projectPath to $outputDir"

# Load the SSAS Project File
$projectXml = New-Object System.Xml.XmlDocument
$projectXml.Load($projectPath);

function DeserializeProjectItems($xpath, $objectType){
    Write-Verbose "Deserialise $objectType";
    Select-Xml -Xml:$projectXml -XPath:$xpath | % {
        $path = Join-Path $projectDir $_.Node.InnerText;
        DeserializePathAs $path $objectType; # returns item to pipeline
    }
}

function DeserializePathAs($path, $objectType){
    $reader = New-Object System.Xml.XmlTextReader $path;
    try{
        $majorObject = New-Object $objectType;
        [Microsoft.AnalysisServices.Utils]::Deserialize($reader, $majorObject); # returns item to pipeline
    }finally{
        $reader.Close();
    }
}

# Deserialize the Database file onto the Database object
$databaseRelPath = $projectXml.SelectSingleNode("//Database/FullPath").InnerText;
$databasePath = Join-Path $projectDir $databaseRelPath;
$reader = New-Object System.Xml.XmlTextReader $databasePath;
[void] [Microsoft.AnalysisServices.Utils]::Deserialize($reader, $database);

# And all the other project items
DeserializeProjectItems '//DataSources/ProjectItem/FullPath' 'Microsoft.AnalysisServices.RelationalDataSource' | % {
    [void] $database.DataSources.Add($_);
}
DeserializeProjectItems '//DataSourceViews/ProjectItem/FullPath' 'Microsoft.AnalysisServices.DataSourceView' | % {
    [void] $database.DataSourceViews.Add($_);
}
DeserializeProjectItems '//Roles/ProjectItem/FullPath' 'Microsoft.AnalysisServices.Role' | % {
    [void] $database.Roles.Add($_);
}
DeserializeProjectItems '//Dimensions/ProjectItem/FullPath' 'Microsoft.AnalysisServices.Dimension' | % {
    [void] $database.Dimensions.Add($_);
}
DeserializeProjectItems '//MiningModels/ProjectItem/FullPath' 'Microsoft.AnalysisServices.MiningModel' | % {
    [void] $database.MiningModels.Add($_);
}

# When deserializing cube we need to account for dependencies (partitions)
# This is cribbed this off of DDarden's code on codeplex
Write-Verbose "Deserialise Microsoft.AnalysisServices.Cube";
Select-Xml -Xml:$projectXml -XPath:'//Cubes/ProjectItem/FullPath' | % {
    $path = Join-Path $projectDir $_.Node.InnerText;

    $cube = DeserializePathAs $path 'Microsoft.AnalysisServices.Cube';
    [void] $database.Cubes.Add($cube);

    $dependencies = $_.Node.SelectNodes('../Dependencies/ProjectItem/FullPath');
    foreach($dependency in $dependencies){
        $path = Join-Path $projectDir $dependency.InnerText;
        $partitionXml = (Select-Xml -Path:$path -XPath:/).Node;

        # .partitions file as loaded doesn't have 'Name' node populated for MeasureGroup
        # need to fix that for deserialization to work
        # NB: don't think we care what name we use, so just use ID
        Select-Xml -Xml:$partitionXml -XPath://AS:MeasureGroup/AS:ID -Namespace:$ns |
            % { 
                $idNode = $_.Node;
                $nameNode = $idNode.ParentNode.ChildNodes | ? { $_.Name -eq 'Name' } | Select-Object -First:1;
                if(!$nameNode){
                    $nameNode = $idNode.OwnerDocument.CreateElement('Name', $ns.AS);
                    $nameNode.InnerText = $idNode.InnerText;
                    [void] $idNode.ParentNode.InsertAfter($nameNode, $idNode);
                }
            }

        # now we can deserialise this 'cube'
        $reader = New-Object System.Xml.XmlNodeReader $partitionXml;
        $tempCube = New-Object 'Microsoft.AnalysisServices.Cube';
        $tempCube = [Microsoft.AnalysisServices.Utils]::Deserialize($reader, $tempCube);

        # ..and then copy the partitions from this 'cube' into the original cube
        foreach($tempMeasureGroup in $tempCube.MeasureGroups){
            $measureGroup = $cube.MeasureGroups.Find($tempMeasureGroup.ID);
            $tempPartitions = @($tempMeasureGroup.Partitions);
            $tempPartitions | % { [void] $measureGroup.Partitions.Add($_) };
        }
    }
}

# finally, spit out the output .asdatabase etc...
if(!(Test-Path $outputDir)){
    [void] (mkdir $outputDir)
}
$outputDir = (Resolve-Path $outputDir).Path;

$writer = New-Object System.Xml.XmlTextWriter "$outputDir\$projectName.asdatabase",([System.Text.Encoding]::UTF8)
$writer.Formatting = 'Indented';
[Microsoft.AnalysisServices.Utils]::Serialize($writer, $database, $false);
$writer.Close();

# Also need to copy over 'Miscellaneous' project items into the output folder
# (basically treat them as 'Content' items would be for normal msbuild projects)
pushd $projectDir;
try{
    Select-Xml -Xml:$projectXml -XPath:'//Miscellaneous/ProjectItem' | % { 
        $source = Resolve-Path $_.Node.FullPath; # might be relative to project    
        Copy-Item $source $outputDir -Force -Verbose:($VerbosePreference -eq 'Continue');
    }
}finally{
    popd;
}