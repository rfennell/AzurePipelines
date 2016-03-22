param
(
    [string]$resultsFile,
    [string]$scriptFolder
)


$VerbosePreference ='Continue' # equiv to -verbose

Import-Module $pwd\Pester.psd1
Write-Verbose "Running Pester from $scriptFolder"
$result = Invoke-Pester -PassThru -OutputFile $resultsFile -OutputFormat NUnitXml -Script $scriptFolder
if ($result.failedCount -ne 0)
{ 
    Write-Error "Pester returned errors"
}
