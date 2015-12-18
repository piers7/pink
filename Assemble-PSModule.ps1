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
                if($line.Contains('= Split-Path $MyInvocation.MyCommand.Path')){
                    throw "$functionName - Can''t use MyInvocation.MyCommand.Path in a script module";
                }

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

# return the FileInfo back to the caller
Get-Item $modulePath;