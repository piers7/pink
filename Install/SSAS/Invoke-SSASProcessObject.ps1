[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $serverInstance,
    [Parameter(Mandatory=$true)] [string] $database,
    [string]$cubeName,
    [string]$process = 'ProcessFull',
    [switch]$ignoreErrors,
    # [switch]$robust,
    [switch]$whatif
)

$ErrorActionPreference = 'stop';
$scriptDir = Split-Path (Convert-Path $myInvocation.MyCommand.Path);

pushd $scriptDir;
try{
    if(!$process -or ($process -eq 'None')){
        return;
    }

    $objectsToProcess = @();

    $db = .\Get-SSASDatabase.ps1 $serverInstance $database;
    if($cubeName){
        $objectsToProcess += $db.Cubes.GetByName($cubeName);
    <#
    }elseif($robust){
        write-verbose "Using robust processing";
        $objectsToProcess += $db.Dimensions;
        foreach($cube in $db.Cubes){
            $objectsToProcess += $cube.MeasureGroups;
        }
        $objectsToProcess += $cube;
    #>
    }else{
        Write-Verbose "Processing entire SSAS database";
        $objectsToProcess += $db;
    }

    function GetSSASFullObjectName($item){
        $names = new-object System.Collections.Stack;
        $names.Push($item.Name);
        while($item.Parent){
            $item = $item.Parent;
            $names.Push($item.Name);    
        }
        $names -join '.'
    }

    $failed = $false;
    foreach($obj in $objectsToProcess){
        $name = GetSSASFullObjectName $obj;

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
    popd;
}
