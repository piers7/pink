param(
    [Parameter(Mandatory=$true)] [string] $server,
    [Parameter(Mandatory=$true)] [string] $databaseName,
    [Parameter(Mandatory=$true)] [string] $login,
    [Parameter(Mandatory=$true)] [string[]] $roles,
    [switch] $strict
)

$erroractionpreference="stop"
$scriptDir = split-path $MyInvocation.MyCommand.Path
pushd $scriptDir;
try{
    $serverSmo = .\Get-SSASServer.ps1 $server;
    $db = $serverSmo.Databases.GetByName($databaseName);
    $name = $login;

    foreach($role in $roles){
        Write-Verbose "Locating role '$role'"
        $roleObj = $db.Roles.GetByName($role);
        $members = $roleObj.Members;
        $target = "{0}.{1}" -f $roleObj.Parent.Parent,$roleObj.Parent;
        $roleMember = @($members | ? { $_.Name -eq $user.Value })
        if ($roleMember){
            Write-Verbose "$name already member of '$role' on $target";
        }else{
            Write-Host "[SSAS:$target] Grant '$name' $role access"
	        [void] $roleObj.Members.Add($name);
	        [void] $roleObj.Update();
        }
    }
}finally{
    popd;
}
