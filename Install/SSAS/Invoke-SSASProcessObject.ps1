param(
    [Parameter(Mandatory=$true)] [string] $server = 'localhost',
    [Parameter(Mandatory=$true)] [string] $database,
    [string]$cubeName,
    [string]$process = 'ProcessFull',
    [switch]$ignoreErrors,
    [switch]$robust,
    [switch]$whatif
)

function TCQuote($message){
    return $message.Replace('|','||').Replace("'", "|'");
}
function FlagError($message){
    $fullMessage = $message -f $args;
    if($inTeamCity){
        $fullMessage = TCQuote $fullMessage;
        Write-Host "##teamcity[message status='ERROR' text='$fullMessage']"
    }else{
        Write-Warning $fullMessage -ForegroundColor:Red;
    }
}

function FailBuild($message){
    $fullMessage = $message -f $args;
    if($env:TEAMCITY_VERSION){
        $fullMessage = TCQuote $fullMessage;
        "##teamcity[buildStatus status='FAILURE' text='{build.status.text} $fullMessage']"
    }else{
        Write-Warning $fullMessage;
    }
}

$erroractionpreference = 'stop'
pushd (split-path $myInvocation.MyCommand.Path)
try{
    if(!$process -or ($process -eq 'None')){
        return;
    }

    $objectsToProcess = @();

    $db = .\Get-SSASDatabase.ps1 -olapServer:$server -databaseName:$database;
    if($cubeName){
        $objectsToProcess += $db.Cubes.GetByName($cubeName);
    }elseif($robust){
        write-verbose "Using robust processing";
        $objectsToProcess += $db.Dimensions;
        foreach($cube in $db.Cubes){
            $objectsToProcess += $cube.MeasureGroups;
        }
        $objectsToProcess += $cube;
    }else{
        write-verbose "Processing just the db";
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
                    FailBuild $message.Description;
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
