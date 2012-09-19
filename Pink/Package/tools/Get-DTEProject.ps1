param(
    $projectName
)

$stack = new-object system.collections.stack
foreach($topLevelItem in $dte.Solution.Projects){
    [void] $stack.Push($topLevelItem);
}
while($stack.Count -gt 0){
    $item = $stack.Pop();
    switch($item.Kind){

        "{66A26720-8FB5-11D2-AA7E-00C04F688DDE}" {
            #write-host "$($item.Name) is a solution folder"
            foreach($child in $item.ProjectItems){
                # if the item in the solution folder 'project' is a project...
                # ref: http://www.wwwlicious.com/2011/03/envdte-getting-all-projects.html#!/2011/03/envdte-getting-all-projects.html
                # and LOTS OF THANKS I NEARLY DIED WORKING IT OUT
                
                $subProject = $child.SubProject;
                if($subProject){
                    # write-host "Pushing $($subProject.Name) $($subProject.Kind)"
                    [void] $stack.Push($subProject);
                }
            }
        }
        
        # "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}" # C#
        # "{c8d11400-126e-41cd-887f-60bd40844f9e}" # database project       
        # "{54435603-DBB4-11D2-8724-00A0C9A8B90C}" # setup project
        default{
            if($projectName){
                if($item.Name -eq $projectName){
                    $item;
                    return;
                }
            }else{
                $item;
            }
        }
    }
}