Add-Type -AssemblyName:Microsoft.AnalysisServices

<#
.synopsis
Connects to an Analysis Services server using AMO
#>
[CmdLetBinding]
function Get-SSASServer {
    param(
        [Parameter(Mandatory=$true)] $serverInstance
    )

    $srv = New-Object Microsoft.AnalysisServices.Server
    $srv.Connect($serverInstance)
    $srv
}
Export-ModuleMember Get-SSASServer;


<#
.synopsis
Connects to an Analysis Services database using AMO
#>
[CmdLetBinding]
function Get-SSASDatabase {
    param(
        [Parameter(Mandatory=$true)] $serverInstance,
        [Parameter(Mandatory=$true)] $databaseName
    )

    $srv = New-Object Microsoft.AnalysisServices.Server
    $srv.Connect($serverInstance)
    $srv.Databases.GetByName($databaseName);
}
Export-ModuleMember Get-SSASDatabase;


<#
.synopsis
Grants a given Windows Login access to an Analysis Services server
#>
[CmdLetBinding]
function Grant-SSASServerAccess {
    param(
        [Parameter(Mandatory=$true)] [string] $serverInstance,
        [Parameter(Mandatory=$true)] [string] $login,
        [string] $role = 'Administrators'
    )

    try{
        $serverSmo = Get-SSASServer $serverInstance;
        $name = $login;

        Write-Verbose "Locating role '$role'"
        $roleObj = $serverSmo.Roles.GetByName($role);
        $members = $roleObj.Members;
        $target = "{0}" -f $roleObj.Parent;
        $roleMember = @($members | ? { $_.Name -eq $user.Value })
        if ($roleMember){
            write-verbose "$name already member of '$role' on $target";
        }else{
            # Turns out there's no need to specify the SID after all
            # ...which makes it much easier when adding local users to SSAS roles
	        Write-Host "[SSAS:$target] Grant '$name' $role access"
	        # [void] $roleObj.Members.Add($roleMember);
	        [void] $roleObj.Members.Add($name);
	        [void] $roleObj.Update();
        }
    }finally{
    }
}
Export-ModuleMember Grant-SSASServerAccess;


<#
.synopsis
Grants a given Windows Login access to an Analysis Services database
#>
[CmdLetBinding]
function Grant-SSASDatabaseAccess {
    param(
        [Parameter(Mandatory=$true)] [string] $serverInstance,
        [Parameter(Mandatory=$true)] [string] $databaseName,
        [Parameter(Mandatory=$true)] [string] $login,
        [Parameter(Mandatory=$true)] [string[]] $roles
    )

    try{
        $serverSmo = Get-SSASServer $serverInstance;
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
    }
}
Export-ModuleMember Grant-SSASDatabaseAccess;


<#
.synopsis
Utility function to create a formatted name from a SSAS object
#>
function Get-SSASFullObjectName($item){
    $names = New-Object System.Collections.Stack;
    $names.Push($item.Name);
    while($item.Parent){
        $item = $item.Parent;
        $names.Push($item.Name);    
    }
    $names -join '.'
}


<#
.synopsis
Processes an Analysis Services database or cube
#>
[CmdLetBinding]
function Invoke-SSASProcessObject {
    param(
        [Parameter(Mandatory=$true)] [string] $serverInstance,
        [Parameter(Mandatory=$true)] [string] $database,
        [string]$cubeName,
        [string]$process = 'ProcessFull',
        [switch]$ignoreErrors,
        [switch]$robust,
        [switch]$whatif
    )

    try{
        if(!$process -or ($process -eq 'None')){
            return;
        }

        $objectsToProcess = @();

        $db = Get-SSASDatabase $serverInstance $database;
        if($cubeName){
            $objectsToProcess += $db.Cubes.GetByName($cubeName);
        }elseif($robust){
            Write-Verbose "Using object-by-object (robust) processing";
            $objectsToProcess += $db.Dimensions;
            foreach($cube in $db.Cubes){
                $objectsToProcess += $cube.MeasureGroups;
            }
            $objectsToProcess += $cube;
        }else{
            Write-Verbose "Processing entire SSAS database";
            $objectsToProcess += $db;
        }

        $failed = $false;
        foreach($obj in $objectsToProcess){
            $name = Get-SSASFullObjectName $obj;

            if ($whatif){
	            Write-Host "WHATIF: " $process $name -ForegroundColor:Yellow
            }else{
                Write-Verbose "Process: $process $name"
                try{
                    [void] $obj.Refresh();
                    $obj.Process($process);
                }catch [Microsoft.AnalysisServices.AmoException] {
                    $failed = $true;
                    foreach($message in ($_.Exception.Results | Select-Object -ExpandProperty:Messages)){
                        Write-Warning $message.Description;
                    }
                }
            }
        }

        if($failed -and !$ignoreErrors){
            throw 'One or more OLAP objects failed to process. See log above'
        }

    }finally{
    }
}
Export-ModuleMember Invoke-SSASProcessObject;