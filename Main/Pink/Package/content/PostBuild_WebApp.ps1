param(
    [Parameter(Mandatory=$true)]
    $projectPath,
	[Parameter(Mandatory=$true)]
	$configurationName,
	[Parameter(Mandatory=$true)]
	$platformName,
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
$projectXml = new-object System.Xml.XmlDocument
$projectXml.Load($projectPath);

$msbuildNs = $projectXml.PSBase.DocumentElement.xmlns;

$nsMan = @{
    msb = $msbuildNs;
};

$activeConfig = Select-Xml -Xml:$projectXml -Namespace:$nsMan -XPath:'//msb:PropertyGroup' | ? {
    $_.Node.Condition -match [System.Text.RegularExpressions.Regex]::Escape("'$configurationName|$platformName'"); 
} | % { $_.Node };
$webDeploy = $activeConfig.PackageAsSingleFile -eq 'true';

$webDeploy = $false;

if($webDeploy){
    write-verbose "Copying web deployment package"
    $package = [string] $activeConfig.DesktopBuildPackageLocation;
    if(!$package){
        # infer default (VS doesn't serialize it)
        $package = "obj\Debug\Package\{0}.zip" -f $projectXml.SelectSingleNode('//*[local-name() = "AssemblyName"]')."#text"
    }

    Copy-Item -Path:(Join-Path $projectDir $package) -Destination:$outputDir -Verbose;

}else{
    write-verbose "Copying content items"
    $contentItems = [string[]]( 
        Select-Xml -Xml:$projectXml -XPath:'//*[local-name() = "Content"]/@Include' | 
        % { ($_.Node."#text") }
    );
    $contentItems | % {
        $src = Join-Path $projectDir $_;
        $dest = Join-Path $outputDir $_;
        $destFolder = Split-Path $dest;
        if(-not (Test-Path $destFolder)){
            $null = mkdir $destFolder;
        }
        Copy-Item -Path:$src -Destination:$dest;
    }

    write-verbose "Copying binaries"
    Copy-Item -Path:$targetDir -Destination:(Join-Path $outputDir "bin") -Recurse;
}