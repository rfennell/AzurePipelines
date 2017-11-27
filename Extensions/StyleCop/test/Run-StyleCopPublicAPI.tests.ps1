
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
  
    It "should be able to scan a folder for violations with basic summary" {
       Mock import-module -ParameterFilter {$name -eq "Microsoft.TeamFoundation.DistributedTask.Task.Common"}

       # make sure we clean out any log files that are already present, only needed for tests as on an agent the folder is created
       Remove-Item  "$PSScriptRoot\logs\*.*"

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
        -detailedSummary $false `
        -verbose

        $summary = Get-Content "$PSScriptRoot\logs\summary.md" 
        $summary.Length | Should be 6
        $summary[-1].EndsWith("StyleCop found [40] violations across [2] projects") | Should be $true 
    }

    It "should be able to scan a folder for violations with detailed summary" {
        Mock import-module -ParameterFilter {$name -eq "Microsoft.TeamFoundation.DistributedTask.Task.Common"}
 
        # make sure we clean out any log files that are already present, only needed for tests as on an agent the folder is created
      
        Remove-Item  "$PSScriptRoot\logs\*.*"
 
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
         -detailedSummary $true `
         -verbose
         
         $summary = Get-Content "$PSScriptRoot\logs\summary.md" 
         $summary.Length | Should be 46
         $summary[-1].EndsWith("StyleCop found [40] violations across [2] projects") | Should be $true 
     }

} 