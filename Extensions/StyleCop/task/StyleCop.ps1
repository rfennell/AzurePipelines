[CmdletBinding()]
param (
 )

$VerbosePreference ='Continue' # equiv to -verbose

# use the new API to set the variables
$treatStyleCopViolationsErrorsAsWarnings = Get-VstsInput -Name "treatStyleCopViolationsErrorsAsWarnings"
$maximumViolationCount = Get-VstsInput -Name "maximumViolationCount"
$allowableViolationCount = Get-VstsInput -Name "allowableViolationCount"
$showOutput = Get-VstsInput -Name "showOutput"
$cacheResults = Get-VstsInput -Name "cacheResults"
$forceFullAnalysis = Get-VstsInput -Name "forceFullAnalysis"
$additionalAddInPath = Get-VstsInput -Name "additionalAddInPath"
$settingsFile = Get-VstsInput -Name "settingsFile"
$loggingfolder = Get-VstsInput -Name "loggingfolder"
$summaryFileName = Get-VstsInput -Name "summaryFileName"
$sourcefolder = Get-VstsInput -Name "sourcefolder"
$detailedSummary = Get-VstsInput -Name "detailedSummary"

function Invoke-DetailedSummaryBuild {
    Param(
        [string]$loggingfolder,
        [string]$sourceFolder
    )

    $text = ""
    $timeout = 5
    $extension = "*.xml"
    $logsToScan = join-path $loggingfolder $extension
    write-verbose "Waiting for logfiles to appear, can be a delay, will wait for up to $timeOut seconds"
    $count =0
    while((!(Test-Path $logsToScan)) -and ($count -le  $timeout)){
        write-verbose ">" 
        Start-Sleep -s 1;
        $count ++
    }
    
    # add an extra guard in case there are no logs
    if (Test-Path $logsToScan){
        Get-ChildItem  $loggingfolder -Filter $extension |
        Foreach-Object {
            $trimmedProjectName = $_.Name.Substring(0, $_.Name.IndexOf("."))
            Write-Verbose "Writing details for project $trimmedProjectName"
            $content = [xml](Get-Content($_.FullName))
            $text += "### Project $trimmedProjectName `r`n"
            foreach($item in $content.StyleCopViolations.Violation)
            {
                $trimFile = $($Item.Source).Replace("$sourcefolder\$trimmedProjectName\", "")
                $text += "- $($item.RuleId) $($item.Rule) ($trimFile - Line No. $($item.LineNumber))`r`n" 
            }
        }
    } 
    return $text
}

# Run the script that does the work in a separate script
# so we can force it to be loaded in 32bit PowerShell as this is required for disctionary loading
# We need to leave the non-Stylecop bit still function
& "$PSScriptRoot\stylecop64bit.ps1" `
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

# use the old summary
if ([System.Convert]::ToBoolean($detailedSummary) -eq $false) {
    Write-Verbose ("Using short summary")
    Add-Content $summaryMdPath ($result.Summary)
} else {
    Write-Verbose ("Using detailed summary")
    Add-Content $summaryMdPath (Invoke-DetailedSummaryBuild -loggingfolder $loggingfolder -sourcefolder  $sourcefolder)
}

Add-Content $summaryMdPath ("`nStyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)

Write-verbose "Uploading summary results file"
Write-Host "##vso[build.uploadsummary]$summaryMdPath"

# Set the message that will be returned
if ($result.OverallSuccess -eq $false)
{
   $resultMessage = ("StyleCop found [{0}] violations across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
} 
else
{
   $resultMessage = ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $result.TotalViolations, $result.ProjectsScanned)
}

# Determine if the task should error
if ($result.OverallSuccess -eq $false -and [int]$result.TotalViolations -gt [int]$allowableViolationCount)
{
   Write-Error ($resultMessage)
} 
else
{
   Write-Verbose ($resultMessage)
}

