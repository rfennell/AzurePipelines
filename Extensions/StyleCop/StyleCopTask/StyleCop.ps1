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

import-module "stylecop.psm1" 
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common" # to get the upload summary methods


# pickup the build locations from the environment
$result = Invoke-StyleCopForFolderStructure `
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

# the output summary to the artifact folder and the VSTS summary
$summaryMdPath = (join-path $loggingfolder  $summaryFileName)
Write-Verbose ("Placing summary of test run in [{0}]" -f $summaryMdPath)
Add-Content $summaryMdPath "StyleCop"
Add-Content $summaryMdPath ($result.Summary)
Add-Content $summaryMdPath ("`nStyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
Write-verbose "Uploading summary results file"
Write-Host "##vso[build.uploadsummary]$summaryMdPath"

# Set if the build should eb failed or not
if ($result.OverallSuccess -eq $false)
{
   Write-Error ("StyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
} 
elseif ($result.TotalViolations -gt 0 -and $treatViolationsErrorsAsWarnings -eq $true)
{
    Write-Warning ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
} 
else
{
   Write-Verbose ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned) 
}

