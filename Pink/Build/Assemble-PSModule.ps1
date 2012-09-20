param(
    [Parameter(Mandatory=$true)] $path
)

$files = dir $path *.ps1 -Recurse

foreach($file in $files){

}