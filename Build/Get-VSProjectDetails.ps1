<#
.synopsis
Get Visual Studio project metadata from one or more project files

.description
Takes an input stream of FileInfo's and returns a custom object with project metadata
Use this to easily extract lists of projects by version etc...
.Example
.\Get-VSProjectDetails.ps1 | ? { $_.TargetFrameworkVersion -ne 'v3.5' }

#>
param(
    $buildConfig = 'Debug',
    $platformConfig = 'Any CPU',
    $project
)
begin {
    $ErrorActionPreference = 'stop';

    # Need to ensure this condition is treated literally
    $condition = '{0}|{1}' -f $buildConfig,($platformConfig -replace ' ','')
    $condition = [system.text.regularexpressions.regex]::Escape($condition)
    $projectXml = new-object system.xml.xmldocument;


    function process-item($item){
        if($item.FullName){
            $projectPath = $item.FullName;
        }else{
            $projectPath = $item;
        }
        $projectDir = Split-Path $projectPath;
		$projectName = [IO.Path]::GetFileNameWithoutExtension($projectPath);
        
		[void] $projectXml.Load($projectPath);
        
        $projectGlobals = $projectXml.SelectSingleNode('//*[local-name() = "PropertyGroup"]/*[local-name()="OutputType"]/..');

        $propertyGroups = $projectXml.SelectNodes("//*[local-name() = 'PropertyGroup']")
        $matchedConfig = ($propertyGroups | ? { $_.Condition -match $condition }) | Select-Object -First:1;
        if($matchedConfig){
            $outputRelPath = $matchedConfig.OutputPath
        }else{
            $outputRelPath = '??'
        }
        switch -wildcard ($projectGlobals.OutputType){
            '*exe' {
                $extension = '.exe';
                break;
             } 
             default {
                $extension = '.dll'
                break;
             }
        }
        $outputPath = join-path $projectDir $outputRelPath
        if($outputRelPath -match '\$\('){
            $outputPath = $outputRelPath
        }
        $outputItem = (join-path $outputPath $projectGlobals.AssemblyName) + $extension

        $projectDetails = New-Object PSObject -Property:@{
            ProjectName = $projectName;
            Directory = $projectDir;
            # Assembly = $projectGlobals.AssemblyName;
            # Namespace = $projectGlobals.RootNamespace;
            # TargetFrameworkVersion = $projectGlobals.TargetFrameworkVersion;
            FullName = $projectPath;
            OutputPath = $outputRelPath;
            TargetPath = $outputItem;
            Item = $projectXml;
        }
        
        # Add all child -elements- directly
        foreach($element in $projectGlobals.SelectNodes('*')){
            Add-Member -InputObject:$projectDetails -MemberType:NoteProperty -Name:$element.LocalName -Value:$element.InnerText;
        }
        
        # Output to pipeline
        $projectDetails;    
    }
}
process {
	if ($_){
        process-item $_;
	}
}
end{
    if($project){
        process-item $project;
    }
}
