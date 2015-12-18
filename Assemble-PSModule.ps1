param(
    [Parameter(Mandatory=$true)] $scriptFolder,
    $moduleName = ('Pink-' + (Split-Path -Leaf $scriptFolder)),
    $outputFolder = '.\output'
)

$modulePath = "$outputFolder\$moduleName.psm1"
if(!(Test-Path $outputFolder)){
    [void] (mkdir $outputFolder);
}

Write-Host "Assembling $modulePath"
"" | Set-Content $modulePath

dir $scriptFolder *.ps1 | 
    ? { !$_.Name.StartsWith('_') } |
    % { 
        $file = $_;
        Write-Verbose "Including $file"
        Get-Content $file.FullName | ? { $_ -ne '[CmdLetBinding()]' } | # invalid in modules apparently
        & {
            begin {
                $functionName = $_.BaseName; # file name without extension
                $wroteHeader = $false;
                "# begin $file"
            }
            process {
                $line = $_;
                if(!$wroteHeader -and $line -match '\s*param\s*\('){
                    "function $functionName {"
                    $wroteHeader = $true;
                }
                $line;
            }
            end{
                "";
                if($wroteHeader){
                    "} # end $functionName";
                    "Export-ModuleMember -function $functionName;"
                }else{
                    "# end $file"
                }
                "";
                "";
            }
        } | Out-File -Append -FilePath:$modulePath -Encoding:ASCII;
    }