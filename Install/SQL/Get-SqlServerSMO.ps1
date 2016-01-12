param(
    [Parameter(Mandatory=$true)]
    [string] $sqlServer,
    [switch] $check
)

[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") > $null
$smo = new-object Microsoft.SqlServer.Management.Smo.Server $sqlServer;

$smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Server], [string[]]('Version','Edition'));

[string[]] $dbProperties = 'DatabaseSnapshotBaseName','ChangeTrackingEnabled','CreateDate','IsDatabaseSnapshot','IsDatabaseSnapshotBase','ReadOnly','Version', 'Collation', 'ContainmentType'
$smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], $dbProperties);

$smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Agent.Job], [string[]]('Name','IsEnabled'));

if($check -and -not $smo.Version){
    throw "Failed to connect to server $sqlServer";
}
$smo;
