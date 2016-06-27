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
    [string]$summaryFileName
)


$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Entering script StyleCop.ps1"

import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common" # to get the upload summary methods

# pickup the build locations from the environment
$sourcefolder = $Env:BUILD_SOURCESDIRECTORY
$stagingfolder = $Env:BUILD_STAGINGDIRECTORY

# it seems that for file paths if they are set and then unset the base folder is passed so we check for this 
if ($additionalAddInPath -eq $sourcefolder )
{
    $additionalAddInPath = ""
}
if ($settingsFile -eq $sourcefolder )
{
    $settingsFile = ""
}


Write-Verbose ("Source folder (`$Env) [{0}]" -f $sourcefolder) 
Write-Verbose ("Staging folder (`$Env) [{0}]" -f $stagingfolder) 
Write-Verbose ("Logging folder (Param) [{0}]" -f $loggingfolder) 
Write-Verbose ("Treat violations as warnings (Param) [{0}]" -f $treatStyleCopViolationsErrorsAsWarnings) 
Write-Verbose ("Max violations count (Param) [{0}]" -f $maximumViolationCount) 
Write-Verbose ("Show Output (Param) [{0}]" -f $showOutput) 
Write-Verbose ("Cache Results (Param) [{0}]" -f $cacheResults) 
Write-Verbose ("Force Full Analysis (Param) [{0}]" -f $forceFullAnalysis) 
Write-Verbose ("Addition Add-In path (Param) [{0}]" -f $additionalAddInPath) 
Write-Verbose ("SettingsFile (Param) [{0}]" -f $settingsFile) 
Write-Verbose ("Summary FileName (Param) [{0}]" -f $summaryFileName)
 
# the overall results across all sub scans
$overallSuccess = $true
$projectsScanned = 0
$totalViolations = 0

# load the StyleCop classes, this assumes that the StyleCop.DLL, StyleCop.Csharp.DLL,
# StyleCop.Csharp.rules.DLL in the same folder as the StyleCopWrapper.dll
$folder = Split-Path -parent $MyInvocation.MyCommand.Definition
Write-Verbose ("Loading from folder from [{0}]" -f $folder) 
$dllPath = [System.IO.Path]::Combine($folder,"StyleCopWrapper.dll")
Write-Verbose ("Loading DDLs from [{0}]" -f $dllPath) 
Add-Type -Path $dllPath
$scanner = new-object StyleCopWrapper.Wrapper

# Set the common scan options, 
$scanner.MaximumViolationCount = [System.Convert]::ToInt32($maximumViolationCount)
$scanner.ShowOutput = [System.Convert]::ToBoolean($showOutput)
$scanner.CacheResults = [System.Convert]::ToBoolean($cacheResults)
$scanner.ForceFullAnalysis = [System.Convert]::ToBoolean($forceFullAnalysis)
$scanner.AdditionalAddInPaths = @($pwd, $additionalAddInPath) #  in local path as we place stylecop.csharp.rules.dll here
$scanner.TreatViolationsErrorsAsWarnings = [System.Convert]::ToBoolean($treatStyleCopViolationsErrorsAsWarnings)


# the output summary
$summaryMdPath = (join-path $stagingfolder  $summaryFileName)
Write-Verbose ("Placing summary of test run in [{0}]" -f $summaryMdPath)
Add-Content $summaryMdPath "StyleCop"

# look for .csproj files
foreach ($projfile in Get-ChildItem $sourcefolder -Filter *.csproj -Recurse)
{
   Write-Verbose ("Processing the folder [{0}]" -f $projfile.Directory)

   if (![string]::IsNullOrEmpty($settingsFile) -and (Test-Path $settingsFile))
   {
        Write-Verbose "Using settings.stylecop passed as parameter [$settingsFile]"
        $scanner.SettingsFile = $settingsFile
   } else
   {
 
        # find a set of rules closest to the .csproj file
        $settings = Join-Path -path $projfile.Directory -childpath "settings.stylecop"
        if (Test-Path $settings)
        {
                Write-Verbose "Using found settings.stylecop file same folder as .csproj file"
                $scanner.SettingsFile = $settings
        }  else
        {
            $settings = Join-Path -path $sourcefolder -childpath "settings.stylecop"
            if (Test-Path $settings)
            {
                    Write-Verbose "Using settings.stylecop file in solution folder"
                    $scanner.SettingsFile = $settings
            } else 
            {
                    Write-Verbose "Cannot find a local settings.stylecop file, using default rules"
                    $scanner.SettingsFile = "." # we have to pass something as this is a required param
            }
        }
   }


   $scanner.SourceFiles =  @($projfile.Directory)
   $scanner.XmlOutputFile = (join-path $loggingfolder $projfile.BaseName) +".stylecop.xml"
   $scanner.LogFile =  (join-path $loggingfolder $projfile.BaseName) +".stylecop.log"
    
   # Do the scan
   $scanner.Scan()


    # Display the results
    Write-Verbose ("`n")
    Write-Verbose ("Base folder`t[{0}]" -f $projfile.Directory) 
    Write-Verbose ("Settings `t[{0}]" -f $scanner.SettingsFile) 
    Write-Verbose ("Succeeded `t[{0}]" -f $scanner.Succeeded) 
    Write-Verbose ("Violations `t[{0}]" -f $scanner.ViolationCount) 
    Write-Verbose ("Log file `t[{0}]" -f $scanner.LogFile) 
    Write-Verbose ("XML results`t[{0}]" -f $scanner.XmlOutputFile) 

    # add to the summary file
    Add-Content $summaryMdPath ("* Project [{0}] - [{1}] Violations" -f $projfile.BaseName, $scanner.ViolationCount)

    $totalViolations += $scanner.ViolationCount
    $projectsScanned ++
    
    if ($scanner.Succeeded -eq $false)
    {
      # any failure fails the whole run
      $overallSuccess = $false
    }


}


# the output summary
Add-Content $summaryMdPath ("`nStyleCop found [{0}] violations across [{1}] projects" -f $totalViolations, $projectsScanned)
Write-verbose "Uploading summary results file"
Write-Host "##vso[build.uploadsummary]$summaryMdPath"

# Set if the build should eb failed or not
if ($overallSuccess -eq $false)
{
   Write-Error ("StyleCop found [{0}] violations across [{1}] projects" -f $totalViolations, $projectsScanned)
} 
elseif ($totalViolations -gt 0 -and $treatViolationsErrorsAsWarnings -eq $true)
{
    Write-Warning ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $totalViolations, $projectsScanned)
} 
else
{
   Write-Verbose ("StyleCop found [{0}] violations warnings across [{1}] projects" -f $totalViolations, $projectsScanned) 
}


Write-Verbose "Leaving script StyleCop.ps1"