<#
.synopsis
Grants a given Windows Login access to an Analysis Services server
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $serverInstance,
    [Parameter(Mandatory=$true)] [string] $login,
    [string[]] $role = (,'Administrators')
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
$name = $login;

foreach($role in $roles){
    Write-Verbose "Locating role '$role'"
    $roleObj = $serverSmo.Roles.GetByName($role);
    $members = $roleObj.Members;
    $target = "{0}" -f $roleObj.Parent;
    $roleMember = @($members | ? { $_.Name -eq $user.Value })
    if ($roleMember){
        Write-Verbose "$name already member of '$role' on $target";
    }else{
        # Turns out there's no need to specify the SID after all
        # ...which makes it much easier when adding local users to SSAS roles
        Write-Host "[SSAS:$target] Grant '$name' $role access"
        [void] $roleObj.Members.Add($name);
        [void] $roleObj.Update();
    }
}