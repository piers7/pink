[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $serverInstance,
    [Parameter(Mandatory=$true)] [string] $databaseName,
    [Parameter(Mandatory=$true)] [string] $login,
    [Parameter(Mandatory=$true)] [string[]] $roles
)

$ErrorActionPreference = "stop";
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path };

function InternalInvoke($commandName){
    if(Get-Command $commandName -ErrorAction:SilentlyContinue){
        & $commandName $args;
    }else{
        & (Join-Path $scriptDir "$commandName.ps1") $args;
    }
}

$serverSmo = InternalInvoke Get-SSASServer $serverInstance;
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