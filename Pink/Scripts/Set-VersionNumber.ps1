param(
    [Parameter(Mandatory=$true)] [string]
    $version,

    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [IO.FileInfo[]] $files,

    [switch] $checkout
)

# This script updates the version numbers in AssemblyVersionInfo.cs and all install projects within the solution
# Files are checked out first, unless nocheckout is specified
$programFiles32 = $env:ProgramFiles
if (test-path environment::"ProgramFiles(x86)") { $programFiles32 = (gi "Env:ProgramFiles(x86)").Value };

$erroractionpreference = "stop";
$scriptDir = split-path $myinvocation.MyCommand.Path

$tf = "$ProgramFiles32\Microsoft Visual Studio 10.0\Common7\IDE\TF.exe";

function Checkout($files){
  if ($checkout){
    & $tf checkout $files
  }
}

# .Synopsis
# Sets the version number within an assemblyinfo file
function Set-AssemblyInfoVersion($file, $version)
{
   # Stamp the version number back into the assembly info file
   if (!(test-path $file -PathType leaf))
   {
        write-warning "File not found, skipping version update. $file";
   }
   else
   {
     Checkout $file
     $contents = gc $file | ? { -not ($_ -match 'Version\(') }
     $contents += '[assembly: AssemblyVersion("{0}")]' -f $version;
     $contents += '[assembly: AssemblyFileVersion("{0}")]' -f ($version.Replace('*','0'))
     $contents | out-file $file -Encoding:ASCII
   }
}

function ProcessItem($file, [scriptblock] $exec){
    write-verbose "Set version number in $file"
    checkout $file;
    & $exec;
}

function ProcessXmlItem($file, [scriptblock] $exec){
    write-verbose "Set version number in $file"
    checkout $file;
    $xml = new-object system.xml.xmldocument
    $xml.Load($file.FullName);
    & $exec $xml;
    $xml.Save($file.FullName);
}

# Loop over all the files specified
foreach($file in $files){
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
            if($file.Name -match 'AssemblyInfo.cs'){
                ProcessItem $file {
                    Set-AssemblyInfoVersion $file $version;
                }
            }
        }
    }
}