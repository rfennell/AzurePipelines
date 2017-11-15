
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

Describe "StyleCop single file tests for dictionary" {
  
    It "File has 1 SA1650 issue" {
        $result = Invoke-StyleCop -sourcefolders "$PSScriptRoot\testdata\FileWithSA1650Errors.cs" `
                                  -SettingsFile "$PSScriptRoot\testdata\SettingsOnlySA1650.StyleCop" `
                                  -loggingfolder "$PSScriptRoot\logs" `
                                  -runName "TestRun1650"
        $result.Succeeded | Should be $true
        $result.ViolationCount | Should be 1 
    }

} 