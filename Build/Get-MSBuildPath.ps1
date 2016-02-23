# .synopsis Locates the path to MSBuild, based on MSBuild registry keys
param(
    $version,
    [switch]$x86
)

$is64Bit = if([intptr]::Size -eq 4) { $true } else { $false };

$keys = if($is64Bit -and $x86){ 
    dir registry::hklm\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions
} else { 
    dir registry::hklm\SOFTWARE\Microsoft\MSBuild\ToolsVersions
};

$keys = $keys | % { new-object PSObject -Property:@{
            # Item = $_;
            Name = $_.PSChildName;
            Path = $_.GetValue('MSBuildToolsPath');
        }}

if($version){
    # Find matching key for the version specified
    $keys = $keys | ? { $_.Name -eq $version }
}else{
    # Find latest key (highest version number)
    $keys = $keys | Sort-Object -Desc -Property:@{Expression = { [double]::Parse($_.Name) }}
}

$keys | Select-Object -First:1 | % { Join-Path $_.Path 'MSBuild.exe' };