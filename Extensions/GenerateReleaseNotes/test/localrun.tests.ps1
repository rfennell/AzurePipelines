Import-Module -Name "$PSScriptRoot\..\GenerateReleaseNotesTask\GenerateReleaseNotes.psm1" -Force 

Describe "Template Processing Tests" {

    It "can generate a build based report with parents" {
        
        $templateLocation="File"
        $templatefile="..\..\..\SampleTemplates\GenerateReleaseNotes (Original Powershell based)\release-basic-unfied-template.md"
        $inlinetemplate=""
        $env:RELEASE_ENVIRONMENTNAME = "Public"
        $env:BUILD_BUILDID = ""
        $env:BUILD_DEFINITIONNAME ="Validate-ReleaseNotesTask.Master"
        $env:RELEASE_DEFINITIONNAME = ""
        $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = "https://richardfennell.visualstudio.com/"
        $env:SYSTEM_TEAMPROJECT ="GitHub"
        $env:RELEASE_RELEASEID = "796"
        $env:RELEASE_DEFINITIONID = "3"
        $usedefaultcreds="false"
        $unifiedList = "true"

        $maxWi=50
        $maxChanges=50
        $appendToFile=$False
        $showParents=$true
        $wiFilter="Product Backlog Item, Bug"
        $wiStateFilter="Done, To Do, New"
        $generateForCurrentRelease = $false
        $generateForOnlyPrimary = $false

        $env:PAT = "" # to debug locally enter a valid PAT here
        $DebugPreference = "Inquire"

        & "$PSScriptRoot\..\GenerateReleaseNotesTask\GenerateReleaseNotes.ps1" `
        -outputfile $outputfile `
        -outputvariablename $outputvariablename `
        -templatefile $templatefile `
        -inlinetemplate $inlinetemplate `
        -templateLocation $templateLocation `
        -usedefaultcreds $usedefaultcreds `
        -generateForOnlyPrimary $generateForOnlyPrimary `
        -generateForCurrentRelease $generateForCurrentRelease `
        -overrideStageName $overrideStageName `
        -emptySetText $emptySetText `
        -maxChanges $maxChanges `
        -maxWi $maxWi `
        -wiFilter $wiFilter `
        -wiStateFilter $wiStateFilter `
        -showParents $showParents `
        -appendToFile $appendToFile `
        -unifiedList $unifiedList

    }
}