function Invoke-StyleCop
{
  [CmdletBinding()]
  Param(
    [string]$treatStyleCopViolationsErrorsAsWarnings = $true,
    [string]$maximumViolationCount = 1000,
    [string]$showOutput = $true,
    [string]$cacheResults = $false,
    [string]$forceFullAnalysis = $true,
    [string]$additionalAddInPath,
    [string]$settingsFile,
    [string]$loggingfolder,
    [string]$runName,
    $sourcefolders 
    )

    # load the StyleCop classes, this assumes that the StyleCop.DLL, StyleCop.Csharp.DLL,
    # StyleCop.Csharp.rules.DLL in the same folder as the StyleCopWrapper.dll
    $folder = $PSScriptRoot
    Write-Verbose ("Loading from folder from [{0}]" -f $folder) 
    $dllPath = [System.IO.Path]::Combine($folder,"StyleCopWrapper.dll")
    Write-Verbose ("Loading DLLs from [{0}]" -f $dllPath) 
    Add-Type -Path $dllPath
    $scanner = new-object StyleCopWrapper.Wrapper

    # Set the common scan options, 
    $scanner.MaximumViolationCount = [System.Convert]::ToInt32($maximumViolationCount)
    $scanner.ShowOutput = [System.Convert]::ToBoolean($showOutput)
    $scanner.CacheResults = [System.Convert]::ToBoolean($cacheResults)
    $scanner.ForceFullAnalysis = [System.Convert]::ToBoolean($forceFullAnalysis)
    $scanner.AdditionalAddInPaths = @($pwd, $additionalAddInPath) #  in local path as we place stylecop.csharp.rules.dll here
    $scanner.TreatViolationsErrorsAsWarnings = [System.Convert]::ToBoolean($treatStyleCopViolationsErrorsAsWarnings)

    $scanner.SourceFiles =  @($sourcefolders)
    $scanner.XmlOutputFile = (join-path $loggingfolder $runName) +".stylecop.xml"
    $scanner.LogFile =  (join-path $loggingfolder $runName) +".stylecop.log"
    $scanner.SettingsFile = $settingsfile
   
    # Do the scan
    $scanner.Scan()

    # Display the results
    Write-Verbose ("`n")
    Write-Verbose ("Base folder`t[{0}]" -f $sourcefolders) 
    Write-Verbose ("Settings `t[{0}]" -f $scanner.SettingsFile) 
    Write-Verbose ("Succeeded `t[{0}]" -f $scanner.Succeeded) 
    Write-Verbose ("Violations `t[{0}]" -f $scanner.ViolationCount) 
    Write-Verbose ("Log file `t[{0}]" -f $scanner.LogFile) 
    Write-Verbose ("XML results`t[{0}]" -f $scanner.XmlOutputFile) 

    $return = new-object psobject -property @{ViolationCount=$scanner.ViolationCount;Succeeded=$scanner.Succeeded}
    $return

}

function Invoke-StyleCopForFolderStructure
{
   [CmdletBinding()]
    Param(
    [string]$treatStyleCopViolationsErrorsAsWarnings = $true,
    [string]$maximumViolationCount = 1000,
    [string]$showOutput = $true,
    [string]$cacheResults = $false,
    [string]$forceFullAnalysis = $true,    
    [string]$additionalAddInPath,
    [string]$settingsFile,
    [string]$loggingfolder,
    [string]$summaryFileName,
    [string]$sourcefolder 
    )

    # it seems that for file paths if they are set and then unset the base folder is passed so we check for this 
    if ($additionalAddInPath -eq $sourcefolder )
    {
        $additionalAddInPath = ""
    }
    if ($settingsFile -eq $sourcefolder )
    {
        $settingsFile = ""
    }

    Write-Verbose ("Source folder [{0}]" -f $sourcefolder) 
    Write-Verbose ("Logging folder [{0}]" -f $loggingfolder) 
    Write-Verbose ("Treat violations as warnings [{0}]" -f $treatStyleCopViolationsErrorsAsWarnings) 
    Write-Verbose ("Max violations count [{0}]" -f $maximumViolationCount) 
    Write-Verbose ("Show Output [{0}]" -f $showOutput) 
    Write-Verbose ("Cache Results [{0}]" -f $cacheResults) 
    Write-Verbose ("Force Full Analysis [{0}]" -f $forceFullAnalysis) 
    Write-Verbose ("Addition Add-In path [{0}]" -f $additionalAddInPath) 
    Write-Verbose ("SettingsFile [{0}]" -f $settingsFile) 
    Write-Verbose ("Summary FileName [{0}]" -f $summaryFileName)
    
    # the overall results across all sub scans
    $overallSuccess = $true
    $projectsScanned = 0
    $totalViolations = 0
  
    # look for .csproj files
    foreach ($projfile in Get-ChildItem $sourcefolder -Filter *.csproj -Recurse)
    {
        Write-Verbose ("Processing the folder [{0}]" -f $projfile.Directory)

        if (![string]::IsNullOrEmpty($settingsFile) -and (Test-Path $settingsFile))
        {
            Write-Verbose "The settings.stylecop passed the parameter [$settingsFile]"
            Write-Verbose "The IsNullOrEmpty check returned [$([string]::IsNullOrEmpty($settingsFile))]"
            Write-Verbose "The Test-Path check returned [$(Test-Path $settingsFile))]"
        } else
        {
            # find a set of rules closest to the .csproj file
            $settings = Join-Path -path $projfile.Directory -childpath "settings.stylecop"
            if (Test-Path $settings)
            {
                Write-Verbose "Using found settings.stylecop file same folder as .csproj file"
                $SettingsFile = $settings
            }  else
            {
                $settings = Join-Path -path $sourcefolder -childpath "settings.stylecop"
                if (Test-Path $settings)
                {
                    Write-Verbose "Using settings.stylecop file in solution folder"
                    $SettingsFile = $settings
                } else 
                {
                    Write-Verbose "Cannot find a local settings.stylecop file, using default rules"
                    $SettingsFile = "." # we have to pass something as this is a required param
                }
            }
        }

        $results = Invoke-StyleCop -treatStyleCopViolationsErrorsAsWarnings $treatStyleCopViolationsErrorsAsWarnings `
                    -maximumViolationCount $maximumViolationCount `
                    -showOutput $showOutput `
                    -cacheResults $cacheResults `
                    -forceFullAnalysis $forceFullAnalysis `
                    -additionalAddInPath $additionalAddInPath `
                    -settingsFile $settingsFile `
                    -loggingfolder $loggingfolder `
                    -runName $projfile.BaseName `
                    -sourcefolders @($projfile.Directory)

        $totalViolations += $results.ViolationCount
        $projectsScanned ++
        $summary += ("* Project [{0}] - [{1}] Violations `n" -f $projfile.BaseName, $results.ViolationCount)
        
        if ($results.Succeeded -eq $false)
        {
        # any failure fails the whole run
        $overallSuccess = $false
        }

    }

    $return = new-object psobject -property @{TotalViolations=$totalViolations; ProjectsScanned=$projectsScanned; OverallSuccess=$overallSuccess; Summary=$summary}
    $return

}