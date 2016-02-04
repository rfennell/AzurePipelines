param
(
    [string]$TreatStyleCopViolationsErrorsAsWarnings 

)


$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Entering script StyleCop.ps1"

# pickup the build locations from the environment
$stagingfolder = $Env:BUILD_STAGINGDIRECTORY
$sourcefolder = $Env:BUILD_SOURCESDIRECTORY

# have to convert the string flag to a boolean
$treatViolationsErrorsAsWarnings = [System.Convert]::ToBoolean($TreatStyleCopViolationsErrorsAsWarnings)


Write-Verbose ("Source folder (`$Env)  [{0}]" -f $sourcefolder) 
Write-Verbose ("Staging folder (`$Env) [{0}]" -f $stagingfolder) 
Write-Verbose ("Treat violations as warnings (Param) [{0}]" -f $treatViolationsErrorsAsWarnings) 
 
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
$scanner.MaximumViolationCount = 1000
$scanner.ShowOutput = $true
$scanner.CacheResults = $false
$scanner.ForceFullAnalysis = $true
$scanner.AdditionalAddInPaths = @($pwd) # in in local path as we place stylecop.csharp.rules.dll here
$scanner.TreatViolationsErrorsAsWarnings = $treatViolationsErrorsAsWarnings


# look for .csproj files
foreach ($projfile in Get-ChildItem $sourcefolder -Filter *.csproj -Recurse)
{
   Write-Verbose ("Processing the folder [{0}]" -f $projfile.Directory)


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


   $scanner.SourceFiles =  @($projfile.Directory)
   $scanner.XmlOutputFile = (join-path $stagingfolder $projfile.BaseName) +".stylecop.xml"
   $scanner.LogFile =  (join-path $stagingfolder $projfile.BaseName) +".stylecop.log"
    
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


    $totalViolations += $scanner.ViolationCount
    $projectsScanned ++
    
    if ($scanner.Succeeded -eq $false)
    {
      # any failure fails the whole run
      $overallSuccess = $false
    }


}


# the output summary
Write-Verbose ("`n")
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