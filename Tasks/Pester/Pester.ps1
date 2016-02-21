param
(
    [string]$resultsFile,
    [string]$scriptFolder
)


$VerbosePreference ='Continue' # equiv to -verbose

Import-Module $pwd\Pester.psd1
Write-Verbose "Running Pester from $scriptFolder"
Invoke-Pester -OutputFile $resultsFile -OutputFormat NUnitXml -Script $scriptFolder
