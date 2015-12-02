param(
    [Parameter(Mandatory=$true)] $serverUrl,
    [Parameter(Mandatory=$true)] $targetPath
)

$ErrorActionPreference = 'stop';

if($targetPath.StartsWith('/')){ $targetPath = $targetPath.Substring(1); }

# default the webservice endpoint if not fully supplied (prefer if it was mind)
if ($serverUrl.EndsWith('reports', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += 'erver/ReportService2010.asmx'
}elseif ($serverUrl.EndsWith('reportserver', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += '/ReportService2010.asmx'
}

function CombinePath($parent, $child){
    if($parent.EndsWith('/')){
        return $parent + $child;
    }else{
        return $parent +'/' + $child;
    }
}

$parentPath = '/';
$pathParts = $targetPath.Split('/');
$rs = New-WebServiceProxy -Uri:$serverUrl -UseDefaultCredential;

foreach($pathPart in $pathParts){
    # Ensure destination folder level exists, or create it
    $folderExists = $false
    $thisPath = CombinePath $parentPath $pathPart;
    foreach($child in $rs.ListChildren($parentPath, $false)){
	    if ($child.Path -eq $thisPath){
		    $folderExists = $true;
            continue;
	    }
    }
    if (-not $folderExists){
        Write-Verbose "Creating SSRS folder $thisPath";
	    [void] $rs.CreateFolder($pathPart, $parentPath, $null)
    }
    $parentPath = $thisPath;
}