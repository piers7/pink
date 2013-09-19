param(
    [Parameter(Mandatory=$true)] [string] $version,
    $versionNumberPattern = "#.#.+1.0",
    [switch] $checkInVersionFile
)

switch($version.GetType()){
    "System.IO.FileInfo" {
        write-verbose "Load version number from $version"
        $version = Get-Content $version | Select-Object -First:1;
        break;
    }
    default {
    
    }
}

if (!$version) {
	$version = '0.0.0.0';
}
$oldVersion = $version;
write-verbose "Old version was $oldVersion";

$oldVersionParts = $oldVersion.Split('.');
$patternParts = $versionNumberPattern.Split('.');

$newVersionParts = [int[]]0,0,0,0;
for($i = 0; $i -lt 4; $i++){
    $patternPart = $patternParts[$i];
    write-verbose "Part $i is $patternPart";
    if($patternPart.StartsWith('+')){
        $eval = "$($oldVersionParts[$i]) $patternPart";
        write-verbose "  Eval $eval";
        $newVersionParts[$i] = invoke-expression $eval;
    }elseif($patternPart.StartsWith('#')){
        $newVersionParts[$i] = $oldVersionParts[$i];
    }else{
        $newVersionParts[$i] = $patternPart;
    }
}

$newVersion = $newVersionParts -join '.';
write-verbose "New Version is $newVersion";
$newVersion;