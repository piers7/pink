<#
.synopsis
Extracts checkin comments from TeamCity's REST api for a particular build (normally the current one)
PW 2015
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    $buildId,
    [Parameter(Mandatory=$true)]
    $serverUri = 'http://teamcity:8070',
    [switch] $asMarkdown
)

function Load-Xml($uri){
    $response = Invoke-WebRequest -Uri:$uri;
    [xml]($response.Content);
}

# Nice non-iterative version as per http://stackoverflow.com/a/25515487/26167

$changes = Load-Xml "$serverUri/guestAuth/app/rest/changes?locator=build:(id:$buildId)&fields=count,change:(version,date,username,comment)"
$changesParsed = $changes.SelectNodes('//change') | Select-Object Version,UserName,@{Name='date';Expression={[DateTime]::ParseExact($_.date, 'yyyyMMddTHHmmsszzzz', $null)}},Comment
if(!$asMarkdown){
    $changesParsed
}else{
    "# Release Notes";
    ""
    $changesParsed | % { "  - [{0:yyyyMMdd}] {1} ({2})" -f $_.date,$_.comment,$_.username }
    ""
    "[More Details]($serverUri/viewLog.html?buildId=$buildId)"
}