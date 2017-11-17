
write-warning "Processor Architecture $env:Processor_Architecture"

# Check that the required powershell module is loaded if it is remove it as it might be an older version
if ((get-module -name StyleCop ) -ne $null)
{
  remove-module StyleCop 
} 

write-warning "PSScriptRoot is $PSScriptRoot"

# Make sure we have a log folder
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" >$null 2>&1

Describe "Functional Test using task API" {
  
    It "should be able to scan a folder for violations" {
       Mock import-module -ParameterFilter {$name -eq "Microsoft.TeamFoundation.DistributedTask.Task.Common"}

        & "$PSScriptRoot\..\task\stylecop.ps1" `
        -treatStyleCopViolationsErrorsAsWarnings $true `
        -maximumViolationCount 1000 `
        -showOutput $true `
        -cacheResults $false `
        -forceFullAnalysis $true `
        -additionalAddInPath "" `
        -settingsFile "" `
        -loggingfolder "$PSScriptRoot\logs" `
        -summaryFileName "summary.md" `
        -sourcefolder "$PSScriptRoot\testdata\StyleCopSample" `
        -verbose

        $summary = Get-Content "$PSScriptRoot\logs\summary.md" -last 1
        $summary.EndsWith("StyleCop found [40] violations across [2] projects") | Should be $true 
    }


} 