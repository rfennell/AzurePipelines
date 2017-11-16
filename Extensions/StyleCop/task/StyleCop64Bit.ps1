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

# Using this extra script so I can just reload in 32bit the bits I need
# This way of doing it seems the least complex, means the module and 
# VSTS task script don't have to worry over 32/64bit issues


if ($env:Processor_Architecture -ne "AMD64")   
{ 
    # Get the command parameters
    $args = $myinvocation.BoundParameters.GetEnumerator() | ForEach-Object {$($_.Value)}
    write-verbose 'Launching x64 PowerShell'
    &"$env:windir\sysnative\windowspowershell\v1.0\powershell.exe" -noprofile -executionpolicy bypass -file $myinvocation.Mycommand.path $args
    exit
}
write-verbose "Running in 64bit PowerShell at this point as dictionaries loaded by StyleCop are 64bit only."

import-module "$PSScriptRoot\stylecop.psm1" 

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

# Need to get the results back to the calling script
# As we have have changed 64 to 32 bit using a file as it is trusted
$result | Export-Clixml $sourcefolder\results.xml

