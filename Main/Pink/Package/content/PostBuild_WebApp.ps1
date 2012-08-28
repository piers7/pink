param(
    [Parameter(Mandatory=$true)]
    $projectPath,
    [Parameter(Mandatory=$true)]
    $targetDir,
    [Parameter(Mandatory=$true)]
    $outputDir
)

$ErrorActionPreference = 'stop';
if(Test-Path $outputDir){
    Remove-Item $outputDir -Recurse -Force;
}
$null = mkdir $outputDir;

$projectDir = Split-Path $projectPath;

$contentItems = [string[]]( 
    Select-Xml -Path:$projectPath -XPath:'//*[local-name() = "Content"]/@Include' | 
    % { ($_.Node."#text") }
);
# Copy-Item $projectDir $outputDir -Recurse -Include:$contentItems;

$contentItems | % {
    $src = Join-Path $projectDir $_;
    $dest = Join-Path $outputDir $_;
    $destFolder = Split-Path $dest;
    if(-not (Test-Path $destFolder)){
        $null = mkdir $destFolder;
    }
    Copy-Item -Path:$src -Destination:$dest;
}

Copy-Item -Path:$targetDir -Destination:(Join-Path $outputDir "bin") -Recurse;