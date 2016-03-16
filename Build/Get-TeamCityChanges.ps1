<#
.synopsis
Extracts checkin comments from TeamCity's REST api for a particular build (normally the current one)
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    $buildId,
    [Parameter(Mandatory=$true)]
    $serverUri = 'http://teamcity:8070',
    [switch] $asMarkdown,
    [switch] $noProxy
)

function Load-Xml($uri){
    if(Get-Command Invoke-WebRequest -ErrorAction:SilentlyContinue){
        $response = Invoke-WebRequest -Uri:$uri;
        [xml]($response.Content);
    }else{
        # Invoke-WebRequest not available on PS 2
        $client = New-Object System.Net.WebClient
        if($noProxy){
	        $client.Proxy = $null;
        }
        if($client.Proxy){
	        Write-Verbose "Retrieving $uri using proxy $($client.Proxy.GetProxy($uri))";
        }else{
	        Write-Verbose "Retrieving $uri";
        }
        $response = $client.DownloadString($uri);
        [xml]$response;
    }
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