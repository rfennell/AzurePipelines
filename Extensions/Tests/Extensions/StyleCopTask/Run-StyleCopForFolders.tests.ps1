# Load the script under test
import-module "$PSScriptRoot\..\..\..\stylecop\stylecoptask\StyleCop.psm1"
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs"


Describe "StyleCop folder based tests" {
  
    It "Solution has 49 issues" {
        $result = Invoke-StyleCopForFolderStructure -sourcefolder "$PSScriptRoot\testdata\StyleCopSample" `
                                  -loggingfolder "$PSScriptRoot\logs"                                   
        $result.OverallSuccess | Should be $true
        $result.TotalViolations | Should be 49
        $result.ProjectsScanned | Should be 2
    }
}

