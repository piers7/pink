<#
.Synopsis
Stamps the version number into the input files suppled on the pipeline.
The version number is stamped in in different ways depending on the file type
(wix, nuspec, assemblyinfo etc...)
Since System.Version can't handle wildcards, no validation on the version string
is performed. It is your responsibility to provide a valid version string for the file types provided.
Read-only files are ignored, unless force is specified.
If operating under TFS, check the files out first
#>
param(
    [Parameter(Mandatory=$true)] [string]
    $version,

    $fileVersion = $version,
    $informationalVersion = $version,

    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [IO.FileInfo[]] $files,

    [switch] $force # if set, version numbers will be set in read-only files. For TFS, checkout first instead of this
)

$programFiles32 = $env:ProgramFiles
if (test-path environment::"ProgramFiles(x86)") { $programFiles32 = (gi "Env:ProgramFiles(x86)").Value };

$erroractionpreference = "stop";
$scriptDir = split-path $myinvocation.MyCommand.Path

function EnsureWritable([io.fileinfo]$file){
    if(!$file.IsReadOnly) { return $true; }
    if($force){
        $file.IsReadOnly = $false;
        return $true;
    }else{
        write-warning "Skipping $file as write protected";
        return $false;
    }
}

# .Synopsis
# Sets the version number within an assemblyinfo file
function Set-AssemblyInfoVersion($file, $version)
{
    if(!(EnsureWritable $file)){ return;}
    
    write-verbose "Set version number in $file"
    $contents = gc $file | ? { -not ($_ -match 'Version\(') }
    $contents += '[assembly: AssemblyVersion("{0}")]' -f $version;
    $contents += '[assembly: AssemblyFileVersion("{0}")]' -f ($fileVersion.Replace('*','0'));
    $contents += '[assembly: AssemblyInformationalVersion("{0}")]' -f $semVer;
    $contents | out-file $file -Encoding:ASCII
    
    # Revert afterwards? Seems like this might just cause even more problems with TFS
    # if($wasReadOnly){ $file.IsReadOnly = $true; }
}

function ProcessItem($file, [scriptblock] $exec){
    if(!(EnsureWritable $file)){ return;}

    write-verbose "Set version number in $file"
    & $exec;
}

function ProcessXmlItem($file, [scriptblock] $exec){
    if(!(EnsureWritable $file)){ return;}
    
    write-verbose "Set version number in $file"
    $xml = new-object system.xml.xmldocument
    $xml.Load($file.FullName);
    & $exec $xml;
    $xml.Save($file.FullName);
}

# Loop over all the files specified
foreach($file in $files){
    if(!$file.Exists) { continue; }
    switch($file.Extension){
        ".nuspec" {
            ProcessXmlItem $file {
                param($xml)
                $xml.package.metadata.version = $version;
            }
            break;
        }
        ".wxs" {
            ProcessXmlItem $file {
                param($xml)
                $xml.Wix.Product.Version = $version;
            }
            break;    
        }
        default {
            if($file.Name -like 'Assembly*Info.cs'){
                ProcessItem $file {
                    Set-AssemblyInfoVersion $file $version;
                }
            }
        }
    }
}