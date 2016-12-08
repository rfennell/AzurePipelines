[CmdletBinding()]
param
(
    [string]$scriptFolder,
    [string]$resultsFile,
    [string]$run32Bit,
    [string]$moduleFolder
)


if ($run32Bit -eq $true -and $env:Processor_Architecture -ne "x86")   
{
    # Get the command parameters
    $args = $myinvocation.BoundParameters.GetEnumerator() | ForEach-Object {$($_.Value)}
    write-warning 'Re-launching in x86 PowerShell'
    &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noprofile -executionpolicy bypass -file $myinvocation.Mycommand.path $args
    exit
}
write-verbose "Running in $($env:Processor_Architecture) PowerShell" -verbose

if ([string]::IsNullOrEmpty($moduleFolder))
{
    # we have no module path specified so use the copy we have in this task
    $moduleFolder = "$pwd\3.4.3"
}

Write-Verbose "Loading Pester module from [$moduleFolder]" -verbose
Import-Module $moduleFolder\Pester.psd1
Write-Verbose "Running Pester from [$scriptFolder] output sent to [$resultsFile]" -verbose

$result = Invoke-Pester -PassThru -OutputFile $resultsFile -OutputFormat NUnitXml -Script $scriptFolder
if ($result.failedCount -ne 0)
{ 
    Write-Error "Pester returned errors"
}
