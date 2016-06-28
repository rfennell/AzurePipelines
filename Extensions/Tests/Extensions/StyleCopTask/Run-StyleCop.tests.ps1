# Load the script under test
import-module "$PSScriptRoot\..\..\..\stylecop\stylecoptask\StyleCop.psm1"

Describe "StyleCop folder based tests" {
  
    It "Solution has 55 issues" {
        $result = Invoke-StyleCopForFolderStructure -sourcefolder "C:\projects\vsts\VSTSBuildTaskValidation\StyleCopSample" `
                                  -loggingfolder $PSScriptRoot -verbose
                                  
        $result.OverallSuccess | Should be $true
        $result.TotalViolations | Should be 55 
        $result.ProjectsScanned | Should be 2
    }
}


Describe "StyleCop single file tests" {
  
    It "File has 7 issues" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWith7Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\AllSettingsEnabled.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 7 
    }

    It "File has 7 issues and treating issues as errors" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWith7Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\AllSettingsEnabled.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun" `
                                  -treatStyleCopViolationsErrorsAsWarnings $false
        $result.Succeeded | Should be $false
        $result.ViolationCount | Should be 7 
    }


    It "File has 3 issues due to reduced ruleset" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWith7Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\SettingsDisableSA1200.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 3 
    }


     It "File has 0 issues" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWith0Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\AllSettingsEnabled.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 0 
    }

     It "File has 3 issues" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWith3Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\AllSettingsEnabled.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 3 
    }

       It "File has 1 SA1650 issue" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\FileWithSA1650Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\SettingsOnlySA1650.StyleCop" `
                                  -loggingfolder $PSScriptRoot `
                                  -runName "TestRun"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 1 
    }

} 