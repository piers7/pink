<#
.Synopsis
Returns a hashtable of TeamCity system build properties for the current build,
or an empty hashtable if not running under TeamCity
#>
[CmdLetBinding()]
param(
    # Path to the .properties file for this build (determined automatically)
    $file = $env:TEAMCITY_BUILD_PROPERTIES_FILE + ".xml",

    # Whether or not the script is running under TeamCity (determined automatically)
    [switch] $inTeamCity = (![String]::IsNullOrEmpty($env:TEAMCITY_VERSION)),

    # Whether TeamCity properties should be resolved (eval'd) as powershell expressions if they start with $
    # This enables objects to be passed in (eg arrays) that would otherwise just be strings
    [switch] $resolveExpressions
)

$buildProperties = @{};
if($inTeamCity){
    Write-Verbose "Loading TeamCity properties from $file"
    $file = (Resolve-Path $file).Path;

    $buildPropertiesXml = New-Object System.Xml.XmlDocument
    $buildPropertiesXml.XmlResolver = $null; # force the DTD not to be tested
    $buildPropertiesXml.Load($file);
    foreach($entry in $buildPropertiesXml.SelectNodes("//entry")){
        $key = $entry.key;
        $value = $entry.'#text';
        if($value -and $value.StartsWith('$') -and $resolveExpressions){
            # This allows us to use PowerShell expression syntax to get strong-types into PowerShell
            $value = Invoke-Expression $value;
        }
        $buildProperties[$key] = $value;
    }
}
$buildProperties;