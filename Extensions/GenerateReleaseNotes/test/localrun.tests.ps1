Import-Module -Name "$PSScriptRoot\..\GenerateReleaseNotesTask\GenerateReleaseNotes.psm1" -Force 

Describe "Template Processing Tests" {

    It "can generate a build based report with parents" {
        
        $templateLocation="File"
        $templatefile="..\..\..\SampleTemplates\GenerateReleaseNotes (Original Powershell based)\build-basic-template.md"
        $inlinetemplate=""
        $stageName = ""
        $buildid = 1762
        $builddefname ="Validate-ReleaseNotesTask.Master"
        $releasedefname = ""
        $collectionUrl = "https://richardfennell.visualstudio.com/"
        $teamproject ="GitHub"
        $releaseid = ""
        $releasedefid = ""
        $usedefaultcreds="false"

        $env:PAT = "<VALID PAT>"
        $DebugPreference = "Inquire"

        $maxWi=50
        $maxChanges=50
        $appendToFile=$False
        $showParents=$true
        $wiFilter="Product Backlog Item, Bug"
        $wiStateFilter="Done, To Do, New"

    
        $builds = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -maxWi $maxWi -maxChanges $maxChanges -wiFilter $wiFilter -wiStateFilter $wiStateFilter -showParents $showParents

        $template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
        $outputmarkdown = Invoke-Template -template $template -builds $builds -releases $releases -stagename $stageName -defname $builddefname -releasedefname $releasedefname
    }
}