<#
.synopsis
Deploys a .asdatabase file to an Analysis Services server as a published OLAP database

.description
Converts a .asdatabase file to an XMLA representation, and executes it to deploy the database.
The target database can be named differently to how it is at design time, and the XML is modified
appropriately - including the ObjectID - to avoid naming collisions.

This script requires the Analysis Services Deployment Tool to be installed locally,
this is typically via an installation of Visual Studio or BIDS.
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] $server,
    [Parameter(Mandatory=$true)] $databaseName,
    [Parameter(Mandatory=$true)] $asdatabase,
    [hashtable]$connections = @{},
    [hashtable]$roleMemberships = @{},
    $sqlVersion = 110,
    $version,
    $description,
    [switch] $clean,
    [switch] $whatif
)

$erroractionpreference="stop"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path

function ResolvePathyThings($path){
    if($path.GetType() -eq [System.Management.Automation.PathInfo]){
        $path = $path.Path;
    }elseif($path.GetType() -ne [System.String]){
        # Assume it's got a FullName property (like a System.IO.FileInfo)
        $path = $path.FullName;
    }
    
    (Resolve-Path $path).Path;
}

$asdatabase = ResolvePathyThings $asdatabase;
$projectName = [IO.Path]::GetFileNameWithoutExtension($asdatabase);
$deploymentOptions = [IO.Path]::ChangeExtension($asdatabase, '.deploymentOptions');

$programFiles32 = $env:ProgramFiles
if (test-path environment::"ProgramFiles(x86)") { $programFiles32 = (gi "Env:ProgramFiles(x86)").Value };
$asDeploy = Resolve-Path "$programfiles32\Microsoft SQL Server\$sqlVersion\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"

function GenerateDeploymentXmla($asdatabase, $xmlaPath, $databaseName){
    if(Test-Path $xmlaPath) { Remove-Item $xmlaPath; }

    Write-Verbose "Generating XMLA to $xmlaPath"
    $asDeployArgs = '"{0}" /d /o:"{1}"' -f $asdatabase,$xmlaPath;

    Write-Verbose "$asDeploy $asDeployArgs"
    $p = Start-Process $asDeploy $asDeployArgs -NoNewWindow -WorkingDirectory:(Convert-Path $pwd) -PassThru;
    $p.WaitForExit();
    if (-not $?){
	    throw "Failed to generate XMLA: errors were reported above";
    }
    if (-not (Test-Path $xmlaPath)){
	    throw New-Object System.IO.FileNotFoundException $xmlaPath
    }
    
    if($databaseName){
        Write-Verbose "Re-write the generated XMLA to set database name as '$databaseName'"
        $ns = @{
            n = 'http://schemas.microsoft.com/analysisservices/2003/engine'
        }
        $xmlaContent = new-object system.xml.xmldocument;
        $xmlaContent.Load($xmlaPath);
        Select-Xml -Xml:$xmlaContent -XPath:'//n:Object/n:DatabaseID' -Namespace:$ns | % { 
            $_.Node.InnerText = $databaseName;
        }
        Select-Xml -Xml:$xmlaContent -XPath:'//n:ObjectDefinition/n:Database' -Namespace:$ns | % { 
            $_.Node.ID = $databaseName;
            $_.Node.Name = $databaseName;
        }
        $xmlaContent.Save($xmlaPath);
    }
}

pushd $scriptDir;
try{
    Write-Host "Deploy OLAP Database '$projectName' to $server as '$databaseName'"

    # It's important we don't do the processing during deployment
    # as we (currently) don't update the datasources until *afterwards*
    # (In future, maybe we should update those in the XMLA also)
    # This also ensures that if we are deploying over the top of a large existing database
    # the deployment doesn't take ages (ie the processing can be deferred)
    if(Test-Path $deploymentOptions){
        Write-Verbose "Amend deployment settings to remove ProcessFull"
        $deploymentOptionsXml = New-Object System.Xml.XmlDocument
        $deploymentOptionsXml.Load($deploymentOptions);
        $deploymentOptionsXml.DeploymentOptions.TransactionalDeployment = "true";
        $deploymentOptionsXml.DeploymentOptions.ProcessingOption = 'DoNotProcess';
        $deploymentOptionsXml.Save($deploymentOptions);
    }else{
        @"
<DeploymentOptions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ddl2="http://schemas.microsoft.com/analysisservices/2003/engine/2" xmlns:ddl2_2="http://schemas.microsoft.com/analysisservices/2003/engine/2/2" xmlns:ddl100_100="http://schemas.microsoft.com/analysisservices/2008/engine/100/100" xmlns:ddl200="http://schemas.microsoft.com/analysisservices/2010/engine/200" xmlns:ddl200_200="http://schemas.microsoft.com/analysisservices/2010/engine/200/200" xmlns:ddl300="http://schemas.microsoft.com/analysisservices/2011/engine/300" xmlns:ddl300_300="http://schemas.microsoft.com/analysisservices/2011/engine/300/300" xmlns:ddl400="http://schemas.microsoft.com/analysisservices/2012/engine/400" xmlns:ddl400_400="http://schemas.microsoft.com/analysisservices/2012/engine/400/400" xmlns:dwd="http://schemas.microsoft.com/DataWarehouse/Designer/1.0">
  <TransactionalDeployment>true</TransactionalDeployment>
  <ProcessingOption>DoNotProcess</ProcessingOption>
</DeploymentOptions>
"@ | Out-File $deploymentOptions;
    }
    
    # Does a non-failing full-path build, without actual resolve check
    $xmla = Join-Path (Split-Path $asdatabase) "$databaseName.xmla";
    
    Write-Verbose "Generate XMLA from the .asdatabase file"
    GenerateDeploymentXmla $asdatabase $xmla -databaseName:$databaseName;

    Write-Verbose "Determine if $databaseName already exists on $server"
    $amoServer = .\Get-SSASServer.ps1 $server;
    $existing = $amoServer.Databases.FindByName($databaseName); # nb: not AMO 2005 compatable
    if($existing){
	    if($clean){
            if($whatif){
                Write-Host "WHATIF: Deployment will drop existing database '$databaseName'";
            }else{
    		    Write-Warning "Dropping existing cube $server $databaseName";
    		    $existing.Drop();
            }
	    }else{
		    Write-Host "Target already exists: this will update $server $databaseName";
	    }
    }else{
	    Write-Verbose "Target $server $databaseName not present - this will be a clean build";
    }
    
    if($whatif){
        return;
    }

    Write-Verbose "Executing XMLA against $server to create $databaseName..."
    # No longer using ascmd as was a 2005 version
    # See http://msdn.microsoft.com/en-us/library/ms365187(v=sql.100).aspx
    $command = [io.file]::ReadAllText($xmla);
    $results = $amoServer.Execute($command) | % { $_.Messages };
    $results | % { $_.Description }
    if ($results.Count -gt 0){
	    throw "Failed to deploy cube: errors were reported above";
    }

    Write-Verbose "Attach to deployed database via AMO"
    $amoServer.Refresh();
    $db = $amoServer.Databases.GetByName($databaseName);
    
    if($connections){
        Write-Verbose "Update datasource connections";
        foreach($item in $connections.GetEnumerator()){
            $dataSource = $db.DataSources.FindByName($item.Key);
            if($dataSource){
                $value = [string]($item.Value);
                Write-Host "Updating connection '$($dataSource.Name)' as $value"
                $dataSource.ConnectionString = $value;
                $dataSource.Update();
            }
        }
    }

    Write-Verbose "Update the version/description on published database as appropriate"
    if($version){
        Write-Host "Stamping the version number as $version";
        $db.Annotations.SetText("Version", $version);
    }
    if($description){
        Write-Host "Set description to $description";
        $db.Description = $description;
    }
    
    Write-Verbose "Commit final updates";
    $db.Update();

    Write-Host "Done";

}finally{
    popd;
}