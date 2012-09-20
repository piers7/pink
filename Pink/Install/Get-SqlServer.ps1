param(
    [Parameter(Mandatory=$true)] [string] $sqlInstance
)
    
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") > $null 

# From LibrarySmo.ps1
#When $sqlInstance passed in from the SMO Name property, brackets
#are automatically inserted which then need to be removed
$sqlInstance = $sqlInstance -replace "\[|\]"

Write-Verbose "Get-SqlServer $sqlInstance"
$serverSmo = new-object Microsoft.SqlServer.Management.Smo.Server $sqlInstance

$serverSmo.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject")
$serverSmo.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject")
$serverSmo.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
$serverSmo.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], "IsSystemObject")

return $serverSmo;