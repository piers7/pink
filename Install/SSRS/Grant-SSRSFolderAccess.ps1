#Requires -version 3.0
param(
    [Parameter(Mandatory=$true)] $serverUrl,
    [Parameter(Mandatory=$true)] $folderPath,
    [Parameter(Mandatory=$true)] [string] $login,
    [string[]] $roles = @() # if you only want to grant Browser access, don't specify any roles
)

$ErrorActionPreference = 'stop';
$scriptDir = split-path $MyInvocation.MyCommand.Path

if (-not $serverPath.StartsWith("/")){ $serverPath = "/" + $serverPath };

$serverUrl = $serverUrl.TrimEnd("/")
if ($serverUrl.ToLowerInvariant().EndsWith('reportserver')){
    throw 'Please supply complete url of SSRS endpoint (including filename/extension)'
}

if(!$roles){
    $roles = @('Browser');
}

# Create the webservice proxy
$rs = New-WebServiceProxy -Uri:$serverUrl -UseDefaultCredential -Namespace:SSRSProxy;
$rsAssembly = $rs.GetType().Assembly;

# multiple calls to new-webserviceproxy within a process return different asssemblies
# so can't use normal type binding and get the right types back
# instead explicitly pull the types out of the assembly that we got this time round
$policyType = $rsAssembly.GetType('SSRSProxy.Policy');
$roleType = $rsAssembly.GetType('SSRSProxy.Role');

# Set permissions
$permsInherited = $true;
$policies = $rs.GetPolicies($serverPath, [ref] $permsInherited);

#foreach($login in @($allowedUsers)){
    $userPolicy = $policies | ? { $_.GroupUserName -eq $login };
    if(!$userPolicy){
		$userPolicy = new-object $policyType;
		$userPolicy.GroupUserName = $login;
		$policies += $userPolicy;
    }

	$userPolicy.Roles = [Array]::CreateInstance($roleType, $roles.Length);
    for($i = 0; $i -lt $roles.Length; $i++){
        $roleName = $roles[$i];
		
		# Bizarrely it craps out if description not supplied. Go figure.
		$roleObj = new-object $roleType;
		$roleObj.Name = $roleName;
		$roleObj.Description = $roleName; # "May view folders, reports and subscribe to reports.";

        $userPolicy.Roles[$i] = $roleObj;
    }
#}
$rs.SetPolicies($serverPath, $policies);
