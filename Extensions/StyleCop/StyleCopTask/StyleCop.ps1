param
(
    [string]$treatStyleCopViolationsErrorsAsWarnings,
    [string]$maximumViolationCount,
    [string]$showOutput,
    [string]$cacheResults,
    [string]$forceFullAnalysis,
    [string]$additionalAddInPath,
    [string]$settingsFile,
    [string]$loggingfolder,
    [string]$summaryFileName,
    [string]$sourcefolder 
)

$VerbosePreference ='Continue' # equiv to -verbose


import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common" # to get the upload summary methods

# Run the script that does the work in a separate script
# so we can force it to be loaded in 32bit PowerShell as this is required for disctionary loading
# We need to leave the non-Stylecop bit still function
& "$PSScriptRoot\stylecop32bit.ps1" `
            -treatStyleCopViolationsErrorsAsWarnings $treatStyleCopViolationsErrorsAsWarnings `
            -maximumViolationCount $maximumViolationCount `
    	    -showOutput $showOutput `
            -cacheResults $cacheResults `
            -forceFullAnalysis $forceFullAnalysis `
            -additionalAddInPath $additionalAddInPath `
            -settingsFile $settingsFile `
            -loggingfolder $loggingfolder `
            -summaryFileName $summaryFileName `
            -sourcefolder $sourcefolder `
            -verbose

# Set if the build should be failed or not getting the results from the file to avoid 32/64 bit issues
$result = Import-Clixml $sourcefolder\results.xml
			
# the output summary to the artifact folder and the VSTS summary
$summaryMdPath = (join-path $loggingfolder  $summaryFileName)
Write-Verbose ("Placing summary of test run in [{0}]" -f $summaryMdPath)
Add-Content $summaryMdPath "###StyleCop"
Add-Content $summaryMdPath ($result.Summary)
Add-Content $summaryMdPath ("`nStyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)

Write-verbose "Uploading summary results file"
Write-Host "##vso[build.uploadsummary]$summaryMdPath"

if ($result.OverallSuccess -eq $false)
{
   Write-Error ("StyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
} 
else
{
   Write-Verbose ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
}
