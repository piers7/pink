param(
	[Parameter(Mandatory=$true)] $project
)

$erroractionpreference = "stop";
$scriptDir = split-path $myinvocation.MyCommand.Path

$startSequence = "rem PINK post build start";
$endSequence = "rem PINK post build end";
function SetPostBuildProp($postBuildEvent, $cmd){
    $existing = $postBuildEvent.Value;
    if($existing){
        # strip existing PINK cmd from post build if present
        $start = [System.Text.RegularExpressions.Regex]::Match($existing, $startSequence);
        $end = [System.Text.RegularExpressions.Regex]::Match($existing, $endSequence);
        if($start.Success -and $end.Success -and $start.Index -lt $end.Index){
            $removeChars = ($end.Index - $start.Index + $end.Length);
            $existing = $existing.Remove(($start.Index-1), $removeChars+1);
        }
    }else{
       $existing = "";
    }
    
    $target = @"
$existing
$startSequence
$cmd
$endSequence
"@
    $target;
    $postBuildEvent.Value = $target;
}

write-host "Project is $project";
if($project.GetType() -eq [System.String]){
    try{
        $p = Get-Project $project
    }catch{
        pushd $scriptDir;
        $p = .\Get-DTEProject | ? { $_.Name -eq $project } | Select-object -First:1
        popd;
    }
}else{
    $p = $project; # assume we were passed the DTE object up-front
}


function CreateProjectItem($project, $targetPath, $script, [switch]$force){
    if(![IO.Path]::IsPathRooted($targetPath)){
        $projectDir = Split-Path $project.FullName;
        $targetPath = Join-Path $projectDir $targetPath;
    }

    $parentPath = Split-Path $targetPath;
    if(-not(Test-Path $parentPath)){
        $null = mkdir $parentPath;
    }

    # if($force -or !(Test-Path $targetPath)){
        Out-File -FilePath:$targetPath -Encoding:ASCII -InputObject:$script -Force:$force -NoClobber:(!$force);
    # }
    [void] $project.ProjectItems.AddFromFile($targetPath);
}

if(!$p){
    throw "Project $project not found";
}

    $projectName = $p.Name;
    $projectDir = Split-Path $p.FullName;
    $postBuildEvent = $p.Properties | ? { $_.Name -eq 'PostBuildEvent' } | Select-Object -First:1;
    
    if(!$postBuildEvent){
        write-warning "PostBuildEvent property not found - you'll have to do this by hand";
    }
    
    $solutionPath = $p.DTE.Solution.Properties.Item('Path').Value;
    $solutionDir = split-path $solutionPath;
            
    write-host "Solution is at $solutionPath"
    switch($p.Kind){
        # C# projects
        # Generally copy whole of build output directory (contains exes, dlls and content items)
        # however different flavours like WebApplication etc... need to be handled too...
        "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}" {
            switch -wildcard ($p.ExtenderNames){
                'WebApplication' {
                    write-host "$projectName is a WebApplication"

                    $projectScriptsDir = Join-Path $projectDir "Scripts";
                    if(-not(Test-Path $projectScriptsDir)){
                        $null = mkdir $projectScriptsDir
                    }
                    $target = Join-Path $projectScriptsDir "PostBuild.ps1";
                    if(!(Test-Path $target)){
                        Copy-Item "$scriptDir\..\content\PostBuild_WebApp.ps1" $target
                    }
                    [void] $p.ProjectItems.AddFromFile($target);

                    $postBuild = @'
powershell -noprofile -noninteractive -command "& '$(ProjectDir)Scripts\PostBuild.ps1' -projectPath:'$(ProjectPath)' -configurationName:'$(ConfigurationName)' -platformName:'$(PlatformName)' -targetDir:'$(TargetDir)' -outputDir:'$(SolutionDir)Output\$(ProjectName)'"
'@
                    break;                
                }           
                
                default {
                    write-host "$projectName is a ClassLibrary"
                    $postBuild = 'xcopy /i /s /y "$(TargetDir)*" "$(SolutionDir)Output\$(ProjectName)"';
                    break;
                }
            }
        }
        
        # Setup projects
        # only get the following macros
        # -BuiltOuputPath
        # -Configuration
        # -ProjectDir
        
        "{54435603-DBB4-11D2-8724-00A0C9A8B90C}" {
            pushd $projectDir;
            $solutionRelPath = Resolve-Path $solutionDir -Relative;
            popd;

            $postBuild = 'xcopy /i /y "$(BuiltOuputPath)" "$(ProjectDir){0}\Output"' -f $solutionRelPath;
            break;
        }
                
        "{c8d11400-126e-41cd-887f-60bd40844f9e}" {
            # Database Projects (GDR)
            # Working directory during post-build event is the targetDir
            # ProjectName/ProjectDir macros doesn't work properly in post-build event: use MSBuildProjectName instead
            # And SolutionDir macro doesn't have a trailing slash
            # Complex scripts don't work properly in post-build events: have to make them a batch / powershell
            # Have to pre-calculate path between solution and project, and hope it doesn't change
            # Use PowerShell as easier to combine paths without getting mucked up with quotes etc...

            write-host "$projectName is a Database Project"

            CreateProjectItem $p PostBuild.bat -force @'
@echo off
set sourceDir=%1
set destinationDir=%2
if exist %destinationdir% rmdir %destinationdir% /s /q 
xcopy /y /s /i %sourcedir% %destinationdir%
'@

            pushd $solutionDir;
            $batchFileRelPath = Join-Path (Resolve-Path $projectDir -Relative) PostBuild.bat;
            if($batchFileRelPath.StartsWith('.\')){
                $batchFileRelPath = $batchFileRelPath.Substring(2);
            }
            popd;
            
            # Relying on the fact that the post-build gets run in the output directory
            # otherwise pass $(OutputPath) and get the batch file to do a pushd ~%dp0
            $postBuild = '"$(SolutionDir)\{0}" "." "$(SolutionDir)\Output\$(MSBuildProjectName)"' -f $batchFileRelPath;
        }
    }

    if($postBuild){
        if($postBuildEvent){
            SetPostBuildProp $postBuildEvent $postBuild;
        }else{
            write-warning "Please put the following in the post-build event manually:"
            write-host $postBuild;
        }
    }
