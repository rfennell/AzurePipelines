write-warning "Processor Architecture $env:Processor_Architecture"
#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    write-warning "Reloading as 64-bit process"
    &"$env:windir\sysnative\windowspowershell\v1.0\powershell.exe" -noprofile -executionpolicy bypass -file $myinvocation.Mycommand.path $args
    exit $lastexitcode
}

# Check that the required powershell module is loaded if it is remove it as it might be an older version
if ((get-module -name StyleCop ) -ne $null)
{
  remove-module StyleCop 
} 

write-warning "PSScriptRoot is $PSScriptRoot"
import-module "$PSScriptRoot\..\task\StyleCop.psm1"

# Make sure we have a log folder
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" >$null 2>&1

Describe "StyleCop folder based tests (using stylecop.setting in each folder and no custom rules DLLs)" {
  
    It "Solution has 40 issues (30 + 10)" {
        $result = Invoke-StyleCopForFolderStructure -sourcefolder "$PSScriptRoot\testdata\StyleCopSample" `
                                  -loggingfolder "$PSScriptRoot\logs"                                   
        $result.OverallSuccess | Should be $true
        $result.TotalViolations | Should be 40
        $result.ProjectsScanned | Should be 2
    }
}

