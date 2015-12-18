<#
.synopsis
A series of utility functions for writing TeamCity Service Messages
This script should be dot-sourced into the caller's scope
Functions can be called outside of TeamCity (eg for local testing) and just write to Output
#>

# .synopsis
# Escapes characters for TeamCity messages
# See https://confluence.jetbrains.com/display/TCD65/Build+Script+Interaction+with+TeamCity
function TeamCity-Escape([string]$message){
    if([string]::IsNullOrEmpty($message)) { return $message; }

    # Replace all banned characters with the same character preceeded by a |
    # This list actually missing some high characters just now
    # oh, and Regex::Escape doesn't actually escape the closing brackets for you (mental)
    # http://msdn.microsoft.com/en-us/library/system.text.regularexpressions.regex.escape%28v=vs.110%29.aspx
    # currently escaping ' | `n `r [ ]

    return [Regex]::Replace($message, '[''\|\n\r\[\]]', '|$0');
}

function Start-TeamCityBlock($taskName){
    if($inTeamCity){
        Write-Host "##teamcity[blockOpened name='$taskName']";
    }else{
        Write-Host "$taskName start";
    }
}
function End-TeamCityBlock($taskName){
    if($inTeamCity){
        Write-Host "##teamcity[blockClosed name='$taskName']";
    }else{
        Write-Host "$taskName end";
        Write-Host;
    }
}

function Write-TeamCityProgress($message){
    if($inTeamCity){
        $message = TeamCity-Escape $message;
        Write-Host "##teamcity[progressMessage '$message']";
    }else{
        Write-Host $message -ForegroundColor:Yellow;
    }
}
function Start-TeamCityProgress($message){
    if($inTeamCity){
        $message = TeamCity-Escape $message;
        Write-Host "##teamcity[progressStart '$message']";
    }else{
        Write-Host $message;
    }
}
function End-TeamCityProgress($message){
    if($inTeamCity){
        $message = TeamCity-Escape $message;
        Write-Host "##teamcity[progressFinish '$message']";
    }else{
        # Write-Host $message
        Write-Host;
    }
}

function Set-TeamCityParameter($name, $value){
    Write-Host ("##teamcity[setParameter name='{0}' value='{1}']" -f (TeamCity-Escape $name),(TeamCity-Escape $value));
}

function Set-TeamCityStatistic($name, $value){
    Write-Host ("##teamcity[buildStatisticValue key='{0}' value='{1}']" -f (TeamCity-Escape $name),(TeamCity-Escape $value));
}

function Write-TeamCityBuildError($message){
    $fullMessage = $message -f $args;
    if($inTeamCity){
        $fullMessage = TeamCity-Escape $fullMessage;
        Write-Host "##teamcity[message status='ERROR' text='$fullMessage']";
    }else{
        Write-Warning $fullMessage;
    }
}

function Write-TeamCityBuildFailure($message){
    $fullMessage = $message -f $args;
    if($inTeamCity){
        $fullMessage = TeamCity-Escape $fullMessage;
        Write-Host "##teamcity[buildStatus status='FAILURE' text='{build.status.text} $fullMessage']";
    }else{
        Write-Error $fullMessage;
    }
}

$parentInvocation = (Get-Variable -Scope:1 -Name:MyInvocation -ValueOnly);
if($MyInvocation.MyCommand.Name.EndsWith('.psm1') -or $parentInvocation.MyCommand -match 'Import-Module'){
    Export-ModuleMember -Function:*-TeamCity*
}