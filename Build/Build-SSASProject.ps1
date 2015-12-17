<#
.Synopsis
Builds a .dwproj into an .asdatabase

.Description
Based on SSASHelper code lifted from Analysis Services project on codeplex
http://sqlsrvanalysissrvcs.codeplex.com/SourceControl/latest#SsasHelper/SsasHelper/ProjectHelper.cs
Thanks to DDarden; I was hoping it was wasn't that hard
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    $projectPath,
    [Parameter(Mandatory=$true)]
    $outputDir,
    $version = '11.0.0.0'
)

$ErrorActionPreference = 'stop';
$asm = [Reflection.Assembly]::Load("Microsoft.AnalysisServices, Version=$version, Culture=neutral, PublicKeyToken=89845dcd8080cc91");

$database = new-object Microsoft.AnalysisServices.Database
$projectPath = (Resolve-Path $projectPath).Path;
$projectDir = Split-Path $projectPath -Parent;
$projectName = [IO.Path]::GetFileNameWithoutExtension($projectPath);

Write-Host "Building $projectPath to $outputDir"

# Load the SSAS Project File
$projectXml = New-Object System.Xml.XmlDocument
$projectXml.Load($projectPath);

function DeserializeProjectItems($xpath, $objectType){
    Write-Verbose "Deserialise $objectType";
    Select-Xml -Xml:$projectXml -XPath:$xpath | % {
        $path = Join-Path $projectDir $_.Node.InnerText;
        $reader = New-Object System.Xml.XmlTextReader $path;
        $majorObject = New-Object $objectType;
        [Microsoft.AnalysisServices.Utils]::Deserialize($reader, $majorObject); # returns item to pipeline
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
DeserializeProjectItems '//Cubes/ProjectItem/FullPath' 'Microsoft.AnalysisServices.Cube' | % {
    [void] $database.Cubes.Add($_);
}

<#
# Deserializing cubes is a bit funky
# again, I've just cribbed this off of DDarden's code
Write-Verbose "Deserialise Microsoft.AnalysisServices.Cube";
Select-Xml -Xml:$projectXml -XPath:'//Cubes/ProjectItem/FullPath' | % {
    $path = Join-Path $projectDir $_.Node.InnerText;
    $reader = New-Object System.Xml.XmlTextReader $path
    $cube = [Microsoft.AnalysisServices.Utils]::Deserialize($reader, (New-Object Microsoft.AnalysisServices.Cube));
    [void] $database.Cubes.Add($cube);

    $dependencies = $_.Node.SelectNodes('../Dependencies/ProjectItem/FullPath');
    foreach($dependency in $dependencies){
        $path = Join-Path $projectDir $dependency.InnerText;

        # todo: some more bits here to bring in the partitions etc...
    }
}
#>

# finally, spit out the output .asdatabase etc...
if(!(Test-Path $outputDir)){
    [void] (mkdir $outputDir)
}
$outputDir = (Resolve-Path $outputDir).Path;

$writer = New-Object System.Xml.XmlTextWriter "$outputDir\$projectName.asdatabase",([System.Text.Encoding]::UTF8)
$writer.Formatting = 'Indented';
[Microsoft.AnalysisServices.Utils]::Serialize($writer, $database, $false);
$writer.Close();