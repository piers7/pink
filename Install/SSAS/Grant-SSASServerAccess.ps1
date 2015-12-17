param(
    [Parameter(Mandatory=$true)] [string] $server,
    [Parameter(Mandatory=$true)] [string] $login,
    [string] $role = 'Administrators',
    [switch] $strict
)

$erroractionpreference="stop"
$scriptDir = split-path $MyInvocation.MyCommand.Path
pushd $scriptDir;
try{
    $parent = .\Get-SSASServer.ps1 $server;
    $name = $login;

    Write-Verbose "Locating role '$role'"
    $roleObj = $parent.Roles.GetByName($role);
    $members = $roleObj.Members;
    $target = "{0}" -f $roleObj.Parent;
    $roleMember = @($members | ? { $_.Name -eq $user.Value })
    if ($roleMember){
        write-verbose "$name already member of '$role' on $target";
    }else{
        # Turns out there's no need to specify the SID after all
        # ...which makes it much easier when adding local users to SSAS roles
	    write-host "Granting $role access to $name on $target"
	    # [void] $roleObj.Members.Add($roleMember);
	    [void] $roleObj.Members.Add($name);
	    [void] $roleObj.Update();
    }
}finally{
    popd;
}
