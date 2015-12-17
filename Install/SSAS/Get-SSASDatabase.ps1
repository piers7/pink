param(
    [Parameter(Mandatory=$true)] $olapServer,
    [Parameter(Mandatory=$true)] $databaseName
)

@"
Microsoft.AnalysisServices
"@.Split([Environment]::NewLine) | ? { ($_ -ne '') -and (-not $_.StartsWith('#')) } | % { 
	$asm = [reflection.assembly]::LoadWithPartialName($_)
	if (-not $asm) { throw Error("Failed to load $_") }
}

$srv = new-object Microsoft.AnalysisServices.Server
$srv.Connect($olapServer)
$srv.Databases.GetByName($databaseName);