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

if ($env:Processor_Architecture -ne "x86")   
{ 
    
    write-warning 'Launching x86 PowerShell'
    # Build the command line
    $file = "$myinvocation.Mycommand.path -treatStyleCopViolationsErrorsAsWarnings $treatStyleCopViolationsErrorsAsWarnings -maximumViolationCount $maximumViolationCount  -showOutput $showOutput  -cacheResults $cacheResults -forceFullAnalysis $forceFullAnalysis -additionalAddInPath -additionalAddInPath -settingsFile $settingsFile -loggingfolder $loggingfolder -summaryFileName $summaryFileName -sourcefolder $sourcefolder "

    &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $file -executionpolicy bypass 
    exit
}
write-verbose "Running in 32bit PowerShell at this point as dictionaries loaded by StyleCop are 32bit only."

import-module "$PSScriptRoot\stylecop.psm1" 

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

