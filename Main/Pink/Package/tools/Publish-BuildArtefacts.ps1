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

write-host "PRojet is $project";
if($project.GetType() -eq [System.String]){
    try{
        $p = Get-Project $project
    }catch{
        pushd $scriptDir;
        $p = .\Get-DTEProjects | ? { $_.Name -eq $project } | Select-object -First:1
        popd;
    }
}else{
    $p = $project; # assume we were passed the DTE object up-front
}

if($p){
    $projectName = $p.Name;
    $projectDir = Split-Path $p.FullName;
    $postBuildEvent = $p.Properties.Item('PostBuildEvent');
    
    $solutionPath = $p.DTE.Solution.Properties.Item('Path').Value;
    $solutionDir = split-path $solutionPath;
            
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
                    Copy-Item ..\content\PostBuild_WebApp.ps1 $target
                    [void] $p.ProjectItems.AddFromFile($target);

                    $postBuild = @'
powershell -noprofile -command "& '$(ProjectDir)Scripts\PostBuild.ps1' -projectPath:'$(ProjectPath)' -targetDir:'$(TargetDir)' -outputDir:'$(SolutionDir)Output\$(ProjectName)'"
'@
                    SetPostBuildProp $postBuildEvent $postBuild;
                    break;                
                }           
                
                default {
                    write-host "$projectName is a ClassLibrary"
                    $postBuild = 'xcopy /i /s /y "$(TargetDir)*" "$(SolutionDir)Output\$(ProjectName)"';
                    SetPostBuildProp $postBuildEvent $postBuild;
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
            SetPostBuildProp $postBuildEvent $postBuild;
            break;
        }
    }

    if($postBuild){
        # $p.Properties.Item("PostBuildEvent").Value = $postBuild;
    }
}

