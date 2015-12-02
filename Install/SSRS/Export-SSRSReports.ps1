param(
    [Parameter(Mandatory=$true)]
    $serverUrl = 'http://localhost/reports',
    [Parameter(Mandatory=$true)]
    $path,
    $targetPath = "$env:temp\Reports"
)

$ErrorActionPreference = 'continue';
$scriptDir = Split-Path $MyInvocation.MyCommand.Path;

if (-not $path.StartsWith("/")){ $path = "/" + $path };

# default the webservice endpoint if not fully supplied (prefer if it was mind)
if ($serverUrl.EndsWith('reports', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += 'erver/ReportService2010.asmx'
}elseif ($serverUrl.EndsWith('reportserver', [stringcomparison]::OrdinalIgnoreCase)){
    $serverUrl += '/ReportService2010.asmx'
}

pushd $scriptDir;
try{
    # Create the webservice proxy
    $rs = New-WebServiceProxy -Uri:$serverUrl -UseDefaultCredential -Namespace:SSRSProxy;
    $rsAssembly = $rs.GetType().Assembly;

    if(!(Test-Path $targetPath)){
        [void] (mkdir $targetPath);
    }

    Write-Host "Exporting from $serverUrl to $targetPath";
    $items = $rs.ListChildren($path, $false);
    foreach($item in $items){
        if($item.TypeName -eq 'Folder')
        {
            continue;
        }
        $extension = & { switch($item.TypeName) {
            "Report" { ".rdl" };
            "DataSource" { ".ds" };
            default { "" };
        }}
        $fileName = $item.Name + $extension;
        $filePath = Join-Path $targetPath $fileName;

        Write-Host "Downloading $($item.TypeName) '$($item.Name)' as $fileName";
        $bytes = $rs.GetItemDefinition($item.Path);
        [System.IO.File]::WriteAllBytes($filePath, $bytes);
    }

}finally{
    popd;
}