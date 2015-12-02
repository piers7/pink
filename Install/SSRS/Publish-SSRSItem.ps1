#Requires -version 2.0
param(
    [Parameter(Mandatory=$true)] $itemPath,
    $itemName,
    [Parameter(Mandatory=$true)] $itemType,   
    $itemProperties,
    [Parameter(Mandatory=$true)] $serverUrl,
    [Parameter(Mandatory=$true)] $targetPath,
    $dataSourcePath = $targetPath,
    $dataSetPath = $targetPath
)

$ErrorActionPreference = 'stop';
$scriptDir = split-path $MyInvocation.MyCommand.Path

# Sanitize input parameters, create derived ones
$itemPath = (Resolve-Path $itemPath).Path; # Takes care of relative-to-caller issues prior to pushd
$itemFolder = split-path $itemPath -parent

if(-not $itemName){
    switch($itemType){
        'Report' {
            $itemName = [IO.Path]::GetFileNameWithoutExtension($itemPath);
        }
        default {
            $itemName = [IO.Path]::GetFileName($itemPath);
        }
    }
}

if (-not $targetPath.StartsWith("/")){ $targetPath = "/" + $targetPath };
if (-not $dataSourcePath.StartsWith("/")){ $dataSourcePath = "/" + $dataSourcePath };
if (-not $dataSetPath.StartsWith("/")){ $dataSetPath = "/" + $dataSetPath };

$serverUrl = $serverUrl.TrimEnd("/")

# default the webservice endpoint if not fully supplied (prefer if it was mind)
if ($serverUrl.EndsWith('reports', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += 'erver/ReportService2010.asmx'
}elseif ($serverUrl.EndsWith('reportserver', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += '/ReportService2010.asmx'
}

function Load-Xml($path){
    $xml = New-Object System.Xml.XmlDocument
    $xml.Load($path);
    $xml;
}

function To-Hashtable($name, $value){
    begin {
        $output = @{};
    }
    process {
        $actualName = & $name $_;
        $actualValue = & $value $_;
        $output[$actualName] = $actualValue;
    }
    end {
        $output;
    }
}

function CreateCatalogItemFromFile(
    [string] $itemType,
    [string] $name,
    [string] $targetPath,
    [IO.FileInfo] $contentPath,
    [hashtable] $properties
){
    Write-Verbose "Uploading $itemType $name to $targetPath"

    # map the hashtable into property objects of the correct type for the webservice
    $props = $emptyProperties;
    foreach($item in $properties.GetEnumerator()){
        $prop = new-object $propertyType
        $prop.Name = $item.Key;
        $prop.Value = $item.Value;
        $props = $props + $prop;
    }

    # load the file content
    [byte[]]$content = [System.IO.File]::ReadAllBytes($contentPath);

    # actually upload the content
    $item = $rs.CreateCatalogItem($itemType, $name, $targetPath, $true, $content, $props, [ref] $warnings);
    if($warnings){
        foreach($warning in $warnings){
            switch($warning.Code) {
                # Smother DataSource / DataSet reference errors (we will fix these later on)
                # alternatively we could check based on 'ObjectName' whether we already published them, but...
                'rsDataSetReferenceNotPublished' { }
                'rsDataSourceReferenceNotPublished' { }

                # Smother this one because way too noisy otherwise
                # Ideally this script would have a verbosity level
                'rsOverlappingReportItems' { }

                default {
                    Write-Warning "$name - $($warning.Message) ($($warning.Code))";
                }
            }
        }
    }
    $item;
}

function ParentPath(
    $targetPath
){
    (Split-Path $targetPath) -replace '\\','/';
}

function FixItemReferences(
    [Parameter(Mandatory=$true)]
    $catalogItem,
    [Parameter(Mandatory=$true)]
    $destinationDir,
    [Parameter(Mandatory=$true)]
    $referenceType,  # 'DataSet' or 'DataSource'
    [scriptblock] $generateTargetName = { $args; } # default is whatever you passed in
){
    if((ParentPath $catalogItem.Path) -ne $destinationDir){
        Write-Verbose "Pointing $($catalogItem.Name) $referenceType references at $destinationDir";
        $refs = $rs.GetItemReferences($catalogItem.Path, $referenceType);
        if($refs){
            $newRefs = $refs | % { 
                $ref = New-Object $itemReferenceType;
                $ref.Name = $_.Name;
                $targetName = & $generateTargetName $_.Name;
                $ref.Reference = $destinationDir + '/' + $targetName; # apparently needs include extension if Sharepoint mode
                $ref;
            }
            [void] $rs.SetItemReferences($catalogItem.Path, $newRefs);
        }
    }
}

$ssrsNs = @{
    rdl = 'http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition';
    sds = 'http://schemas.microsoft.com/sqlserver/reporting/2010/01/shareddatasetdefinition';
};

pushd $scriptDir;
try{
    Write-Verbose "Ensure the destination folders exist"
    .\New-SSRSFolder.ps1 -serverUrl:$serverUrl -targetPath:$targetPath;
    if($dataSourcePath -ne $targetPath){
        .\New-SSRSFolder.ps1 -serverUrl:$serverUrl -targetPath:$dataSourcePath;
    }
    if($dataSetPath -ne $targetPath){
        .\New-SSRSFolder.ps1 -serverUrl:$serverUrl -targetPath:$dataSetPath;
    }

    # Create the webservice proxy
    $rs = New-WebServiceProxy -Uri:$serverUrl -UseDefaultCredential;
    $rsAssembly = $rs.GetType().Assembly;
    $rsNamespace = $rs.GetType().Namespace;

    # multiple calls to new-webserviceproxy within a process return different asssemblies
    # so can't use normal type binding and get the right types back
    # instead explicitly pull the types out of the assembly that we got this time round
    $propertyType = $rsAssembly.GetType($rsNamespace + '.Property');
    $warningType = $rsAssembly.GetType($rsNamespace + '.Warning');
    $dataSourceType = $rsAssembly.GetType($rsNamespace + '.DataSourceDefinition');
    $itemReferenceType = $rsAssembly.GetType($rsNamespace + '.ItemReference');

    $emptyProperties = [Array]::CreateInstance($propertyType, 0);   # empty array of Property type
    $warnings = [Array]::CreateInstance($warningType, 0);   # empty array of Warning type



    Write-Host "Uploading $itemType $itemPath -> $targetPath"
    $catalogItem = CreateCatalogItemFromFile $itemType $itemName $targetPath $itemPath $itemProperties;

}finally{
    popd;
}