<#
.Synopsis
Returns a hashtable of TeamCity system build properties for the current build,
or an empty hashtable if not running under TeamCity
#>
[CmdLetBinding()]
param(
    # Path to the .properties file for this build (determined automatically)
    $file = $env:TEAMCITY_BUILD_PROPERTIES_FILE,

    # Whether TeamCity properties should be resolved (eval'd) as powershell expressions if they start with $
    # This enables objects to be passed in (eg arrays) that would otherwise just be strings
    [switch] $resolveExpressions
)

$buildProperties = @{};
if($file){
    Write-Verbose "Loading TeamCity properties from $file"
    $file = (Resolve-Path $file).Path;

    if([IO.Path]::GetExtension($file) -eq '.xml'){
        $buildPropertiesXml = New-Object System.Xml.XmlDocument
        $buildPropertiesXml.XmlResolver = $null; # force the DTD not to be tested
        $buildPropertiesXml.Load($file);

        $buildPropertiesRaw = $buildPropertiesXml.SelectNodes("//entry") | Select-Object Key,@{Name='Value';Expression={$_.'#text'}}
    }else{
        # The XML file doesn't seem to have half the properties in it
        # so resorting to bludgery to get them out of the text file version
        $buildPropertiesRaw = Get-Content $file | % { 
            $parts = $_ -split '=',2;
            New-Object PSObject -Property:@{
                Key = $parts[0];
                Value = [Regex]::Unescape($parts[1]); # why everything is escaped in raw file I have no idea
            }
        }
    }

    foreach($entry in $buildPropertiesRaw){
        $key = $entry.key;
        $value = $entry.value;
        if($value -and $value.StartsWith('$') -and $resolveExpressions){
            # This allows us to use PowerShell expression syntax to get strong-types into PowerShell
            $value = Invoke-Expression $value;
        }

        Write-Verbose "`tLoaded $key = $value";
        $buildProperties[$key] = $value;
    }
}
$buildProperties;