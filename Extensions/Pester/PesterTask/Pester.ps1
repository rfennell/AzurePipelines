param
(
    [string]$scriptFolder,
    [string]$resultsFile,
    [boolean]$run32Bit 
)

$VerbosePreference ='Continue' # equiv to -verbose

if ($run32Bit -eq $false -and $env:Processor_Architecture -ne "x86")   
{
    # Get the command parameters
    $args = $myinvocation.BoundParameters.GetEnumerator() | ForEach-Object {$($_.Value)}
    write-warning 'Launching x86 PowerShell'
    &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noprofile -executionpolicy bypass -file $myinvocation.Mycommand.path $args
    exit
}
write-verbose "Running in $($env:Processor_Architecture) PowerShell"


Import-Module $pwd\Pester.psd1
Write-Verbose "Running Pester from [$scriptFolder] output sent to [$resultsFile]"

$result = Invoke-Pester -PassThru -OutputFile $resultsFile -OutputFormat NUnitXml -Script $scriptFolder
if ($result.failedCount -ne 0)
{ 
    Write-Error "Pester returned errors"
}
