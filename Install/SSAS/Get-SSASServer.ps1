<#
.synopsis
Connects to an Analysis Services server using AMO
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] $serverInstance
)

Add-Type -AssemblyName:"Microsoft.AnalysisServices, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91";
$srv = New-Object Microsoft.AnalysisServices.Server
[void] $srv.Connect($serverInstance);
if($?){
    $srv;
}