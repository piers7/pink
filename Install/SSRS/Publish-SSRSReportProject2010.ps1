#Requires -version 2.0
param(
    [Parameter(Mandatory=$true)] $reportProjectPath,
    [Parameter(Mandatory=$true)] $serverUrl,
    [Parameter(Mandatory=$true)] $targetPath,
    $dataSourcePath = $targetPath,
    $dataSetPath = $targetPath,
    [hashtable] $connectionStrings,
    [scriptblock] $routingRules,
    [switch] $force
)

$ErrorActionPreference = 'stop';
$scriptDir = split-path $MyInvocation.MyCommand.Path

# Sanitize input parameters, create derived ones
$reportProjectPath = (Resolve-Path $reportProjectPath).Path; # Takes care of relative-to-caller issues prior to pushd
$reportProjectFolder = split-path $reportProjectPath -parent

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

function SelectNameAndFullPath(){
    $input | Select-Object @{
        Name='Name';Expression={[System.IO.Path]::GetFileNameWithoutExtension($_.Name)}
    },@{
        Name='NameWithExtension';Expression={Split-Path $_.Name -Leaf}
    },@{
        Name='FullName';Expression={join-path $reportProjectFolder $_.FullPath}
    },@{
        Name='Item';Expression={$_}
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

function SetDataSources(
    $catalogItem,
    $dataSourceDir,
    $dataSourceName
){
    Write-Verbose "Pointing $($catalogItem.Name) datasource references at $dataSourceDir/$dataSourceName" 
    $refs = $rs.GetItemReferences($catalogItem.Path, 'DataSource');
    if($refs){
        $newRefs = $refs | % { 
            $ref = New-Object $itemReferenceType;
            $ref.Name = $_.Name;
            $ref.Reference = $dataSourceDir + '/' + $dataSourceName;
            $ref;
        }
        [void] $rs.SetItemReferences($catalogItem.Path, $newRefs);
    }
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

$reportProject = Load-Xml ((Resolve-Path $reportProjectPath).Path)
Write-Host "Deploying reports from $(split-path -leaf $reportProjectPath) to $serverUrl ($targetPath)"

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

    Write-Host "Uploading DataSources -> $dataSourcePath"
    $dataSourceItems = @($reportProject.Project.DataSources.ProjectItem | SelectNameAndFullPath);
    foreach($projectItem in $dataSourceItems){
        $name = $projectItem.Name
        $datasourceFile = New-Object System.Xml.XmlDocument;
        $datasourceFile.Load($projectItem.FullName);
        $datasource = $datasourceFile.RptDataSource.ConnectionProperties;
    
        $itemExists = $false;
        foreach($item in $rs.ListChildren($dataSourcePath, $false)){
            Write-Verbose "Comparing $name with $($item.Name) ($($item.TypeName))"
            if (($item.Name -eq $name) -and ($item.TypeName -eq 'DataSource')){
                $itemExists = $true;
                Write-Verbose "Matched $name with $($item.Name) ($($item.TypeName))"
                break;
            }
        }

        if ($itemExists -and -not $force){
	        Write-Host ("`t ... {0} (skipped, already present)" -f $projectItem.Name);
        }else{
	        Write-Host ("`t ... {0}" -f $projectItem.Name);
            $emptyArgs = [object[]]@();
            $dataSourceDefn = [Activator]::CreateInstance($dataSourceType, $emptyArgs); # new-object SSRSProxies.ReportService2010.DataSourceDefinition;
            
            # Take some data source properties from the data source as defined within the SSRS project
            $dataSourceDefn.Extension = $datasource.Extension;

            # Set other properties (or overwrite the above) based on the $connectionStrings hashtable-of-hashtables
            if($connectionStrings -and $connectionStrings.ContainsKey($name)){
                $connectionDetails = $connectionStrings[$name];
                $dataSourceDefn.ConnectString = $connectionDetails.ConnectionString;

                # Splat any remaining items in the hashtable onto properties of the datasource definition object
                foreach($propName in $connectionDetails.Keys | ? { $_ -ne 'ConnectionString' }){
                    $dataSourceDefn.$propName = $connectionDetails.$propName;
                }

            }else{
                Write-Warning "Unable to process connectionstring for $name"
                $dataSourceDefn.ConnectString = '';
            }

            # Credential retrieval defaults to 'prompt'
            # If we specified a username/password, that should be used instead
            if($dataSourceDefn.UserName){
                $dataSourceDefn.CredentialRetrieval = 'Store';

            # otherwise, if the project was using integated security, use that
            }elseif($datasource.IntegratedSecurity -eq "true"){
                $dataSourceDefn.CredentialRetrieval = "Integrated";
            }

            Write-Verbose "Creating datasource $name";
            [void] ($rs.CreateDataSource($name, $dataSourcePath, $false, $dataSourceDefn, $null));
        }
    }

    Write-Host "Uploading DataSets -> $dataSetPath"
    $projectItems = @($reportProject.Project.DataSets.ProjectItem | SelectNameAndFullPath);
    foreach($projectItem in $projectItems){
        Write-Host ("`t ... {0}" -f $projectItem.Name);
        $catalogItem = CreateCatalogItemFromFile 'DataSet' $projectItem.Name $dataSetPath $projectItem.FullName @{}

        # Fix up references
        # Doesn't seem to be any easy way of interrogating the DataSource references from the deployed DataSet
        # (get the references, but not the original DataSource name :-(
        # so...
        $dataSetXml = Load-Xml $projectItem.FullName;
        $ns = @{
            sds = $dataSetXml.DocumentElement.NamespaceURI;
        }
        $dataSourceName = (
            Select-Xml -Path:$projectItem.FullName -XPath:'//sds:DataSet/sds:Query/sds:DataSourceReference' -Namespace:$ns | Select-Object -First:1
            ).Node.'#text';

        SetDataSources $catalogItem $dataSourcePath $dataSourceName;
    }

    Write-Host "Uploading Resources -> $targetPath"
    $projectItems = @($reportProject.Project.Reports.ResourceProjectItem | SelectNameAndFullPath);
    foreach($projectItem in $projectItems){
        Write-Host ("`t ... {0}" -f $projectItem.Name);
        $catalogItem = CreateCatalogItemFromFile 'Resource' $projectItem.NameWithExtension $targetPath $projectItem.FullName @{MimeType='image/jpg'}
    }

    Write-Host "Uploading Reports -> $targetPath"
    $projectItems = @($reportProject.Project.Reports.ProjectItem | SelectNameAndFullPath | ? { -not $_.Name.StartsWith("_") });
    foreach($projectItem in $projectItems){

        $reportDestination = $targetPath;
        if($routingRules){
            # Process destination overrides as required
            $reportDestination = & $routingRules $projectItem.Name
            if($reportDestination) { 
                # Need to check that folder exists
                .\New-SSRSFolder.ps1 -serverUrl:$serverUrl -targetPath:$reportDestination;
            }else{
                # If no override supplied, fall back to default
                $reportDestination = $targetPath 
            };
        }
        
        Write-Host ("`t ... {0}" -f $projectItem.Name);
        $catalogItem = CreateCatalogItemFromFile 'Report' $projectItem.Name $reportDestination $projectItem.FullName @{}

        # Work out namespace (different between 2008, 2012 etc...
        $reportXml = Load-Xml $projectItem.FullName;
        $ns = @{
            rdl = $reportXml.DocumentElement.NamespaceURI;
        }

        # Pull out reference usage for shared Data Set / Data Sources from the RDL
        $sharedDataSourceLookup = Select-Xml -path:$projectItem.FullName -XPath:'//rdl:DataSource[rdl:DataSourceReference]' -Namespace:$ns | 
            Select-Object -ExpandProperty:Node |
            To-Hashtable -Name:{$_.Name} -Value:{$_.DataSourceReference};

        $sharedDataSetLookup = Select-Xml -path:$projectItem.FullName -XPath:'//rdl:DataSet[rdl:SharedDataSet]' -Namespace:$ns | 
            Select-Object -ExpandProperty:Node |
            To-Hashtable -Name:{$_.Name} -Value:{$_.SharedDataSet.SharedDataSetReference};
            
        FixItemReferences $catalogItem $dataSourcePath 'DataSource' -generateTargetName({
            param($dataSourceName);
            return $sharedDataSourceLookup[$dataSourceName];
        }.GetNewClosure());
        
        FixItemReferences $catalogItem $dataSetPath 'DataSet' -generateTargetName:({
            param($dataSetName);
            return $sharedDataSetLookup[$dataSetName];
        }.GetNewClosure());

        # Show all references
        $refs = $rs.GetItemReferences($catalogItem.Path, '')
        if(($VerbosePreference -eq 'continue') -and ($refs)){
            foreach($ref in $refs){
                Write-Verbose ('Referenced {0} ''{1}'' -> {2}' -f $ref.ReferenceType,$ref.Name,$ref.Reference)
            }
        }
    }

}finally{
    popd;
}