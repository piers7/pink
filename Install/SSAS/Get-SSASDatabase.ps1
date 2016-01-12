<#
.synopsis
Connects to an Analysis Services database using AMO
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] $serverInstance,
    [Parameter(Mandatory=$true)] $databaseName
)

Add-Type -AssemblyName:"Microsoft.AnalysisServices, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91";
$srv = New-Object Microsoft.AnalysisServices.Server
$srv.Connect($serverInstance)
if($?){
    $srv.Databases.GetByName($databaseName);
}