param(
    [Parameter(Mandatory=$true)] [string] $version,
    $versionNumberPattern = "#.#.+1.0"
)

$oldVersion = $version;
Write-Verbose "Old version was $oldVersion";

$oldVersionParts = $oldVersion.Split('.');
$patternParts = $versionNumberPattern.Split('.');

$newVersionParts = [int[]]0,0,0,0;
for($i = 0; $i -lt 4; $i++){
    $patternPart = $patternParts[$i];
    Write-Verbose "Part $i is $patternPart";
    if($patternPart.StartsWith('+')){
        $eval = "$($oldVersionParts[$i]) $patternPart";
        Write-Verbose "  Eval $eval";
        $newVersionParts[$i] = Invoke-Expression $eval;
    }elseif($patternPart.StartsWith('#')){
        $newVersionParts[$i] = $oldVersionParts[$i];
    }else{
        $newVersionParts[$i] = $patternPart;
    }
}

$newVersion = $newVersionParts -join '.';
Write-Verbose "New version is $newVersion";
$newVersion;