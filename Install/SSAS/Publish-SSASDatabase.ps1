param(
    [Parameter(Mandatory=$true)] $olapServer,
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

    Write-Host "Generating the XMLA for deployment"
    write-host "Generating XMLA to $xmlaPath"
    $asDeployArgs = '"{0}" /d /o:"{1}"' -f $asdatabase,$xmlaPath;

    Write-Verbose "$asDeploy $asDeployArgs"
    $p = Start-Process $asDeploy $asDeployArgs -NoNewWindow -WorkingDirectory:$pwd -PassThru;
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
    Write-Host "Deploy OLAP Database '$projectName' to $olapServer as '$databaseName'"

    Write-Verbose "Amend deployment settings to remove ProcessFull"
    $deploymentOptionsXml = New-Object System.Xml.XmlDocument
    $deploymentOptionsXml.Load($deploymentOptions);
    $deploymentOptionsXml.DeploymentOptions.TransactionalDeployment = "true";
    $deploymentOptionsXml.DeploymentOptions.ProcessingOption = 'DoNotProcess';
    $deploymentOptionsXml.Save($deploymentOptions);
    
    # Does a non-failing full-path build, without actual resolve check
    $xmla = [IO.Path]::GetFullPath("$databaseName.xmla");
    
    Write-Verbose "Generate the XMLA to deploy the .asdatabase file"
    GenerateDeploymentXmla $asdatabase $xmla -databaseName:$databaseName;

    Write-Verbose "Determine if $databaseName already exists"
    $amoServer = .\Get-SSASServer.ps1 $olapServer;
    $existing = $amoServer.Databases.FindByName($databaseName); # nb: not AMO 2005 compatable
    if($existing){
	    if($clean){
            if($whatif){
                Write-Host "WHATIF: Deployment will drop existing database '$databaseName'";
            }else{
    		    Write-Warning "Dropping existing cube $olapServer $databaseName";
    		    $existing.Drop();
            }
	    }else{
		    Write-Host "Target already exists: this will update $olapServer $databaseName";
	    }
    }else{
	    write-verbose "Target $olapServer $databaseName not present - this will be a clean build";
    }
    
    if($whatif){
        return;
    }

    Write-Verbose "Execute the generated XMLA definition via AMO"
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
    
    Write-Verbose "Update connection details";
    foreach($item in $connections.GetEnumerator()){
        $dataSource = $db.DataSources.FindByName($item.Key);
        if($dataSource){
            $value = [string]($item.Value);
            Write-Host "Updating connection '$($dataSource.Name)' as $value"
            $dataSource.ConnectionString = $value;
            $dataSource.Update();
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

}finally{
    popd;
}