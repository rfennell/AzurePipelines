[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string]$scriptFolder,

    [Parameter(Mandatory)]
    [ValidateScript( {
            (Test-Path (Split-Path $_ -Parent)) -and ($_.split('.')[-1] -eq 'xml')
        })]
    [string]$resultsFile,

    [string]$run32Bit,

    [string]$additionalModulePath,

    [string[]]$Tag,

    [String[]]$ExcludeTag,

    [validateScript( {
            if ([string]::isNullOrWhitespace($_)) {
                $true
            }
            else {
                if (-not($_.Split('.')[-1] -eq 'xml')) {
                    throw "Extension must be XML"
                }
                $true
            }
        })]
    [string]$CodeCoverageOutputFile,

    [string]$CodeCoverageFolder
)

Import-Module -Name "$PSScriptRoot\HelperModule.psm1" -Force

if ($run32Bit -eq $true -and $env:Processor_Architecture -ne "x86") {
    # Get the command parameters
    $args = $myinvocation.BoundParameters.GetEnumerator() | ForEach-Object {
        if (-not([string]::IsNullOrWhiteSpace($_.Value))) {
            If ($_.Value -eq 'True' -and $_.Key -ne 'run32Bit' -and $_.Key -ne 'ForceUseOfPesterInTasks') {
                "-$($_.Key)"
            }
            else {
                "-$($_.Key)"
                "$($_.Value)"
            }
        }

    }
    write-warning "Re-launching in x86 PowerShell with $($args -join ' ')"
    &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noprofile -executionpolicy bypass -file $myinvocation.Mycommand.path $args
    exit
}
Write-Host "Running in $($env:Processor_Architecture) PowerShell"

if ($PSBoundParameters.ContainsKey('additionalModulePath')) {
    Write-Host "Adding additional module path [$additionalModulePath] to `$env:PSModulePath"
    $env:PSModulePath = $additionalModulePath + ';' + $env:PSModulePath
}

if ($PSVersionTable.PSVersion.Major -ge 5 -or (Get-Module -Name PowerShellGet -ListAvailable)) {
    Install-PackageProvider -Name Nuget -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false
    Install-Module -Name Pester -Scope CurrentUser -Force -Repository (Get-PSRepository)[0].Name
}
else {
    Import-Module "$PSScriptRoot\4.3.1\Pester.psd1" -force
}

$Parameters = @{
    PassThru = $True
    OutputFile = $resultsFile
    OutputFormat = 'NUnitXml'
}

if (test-path -path $scriptFolder)
{
    Write-Host "Running Pester from the folder [$scriptFolder] output sent to [$resultsFile]"
    $Parameters.Add("Script", $scriptFolder)
} else {
    Write-Host "Running Pester from using the script parameter [$scriptFolder] output sent to [$resultsFile]"
    $Parameters.Add("Script", (Get-HashtableFromString -line $scriptFolder))
}

if ($Tag) {
    $Tag = $Tag.Split(',').Replace('"', '').Replace("'", "")
    $Parameters.Add('Tag', $Tag)
}
if ($ExcludeTag) {
    $ExcludeTag = $ExcludeTag.Split(',').Replace('"', '').Replace("'", "")
    $Parameters.Add('ExcludeTag', $ExcludeTag)
}
if ($CodeCoverageOutputFile -and (Get-Module Pester).Version -ge '4.0.4') {
    if (-not $PSBoundParameters.ContainsKey('CodeCoverageFolder')) {
        $CodeCoverageFolder = $scriptFolder
    }
    $Files = Get-ChildItem -Path $CodeCoverageFolder -include *.ps1, *.psm1 -Exclude *.Tests.ps1 -Recurse |
        Select-object -ExpandProperty Fullname

    if ($Files) {
        $Parameters.Add('CodeCoverage', $Files)
        $Parameters.Add('CodeCoverageOutputFile', $CodeCoverageOutputFile)
    }
    else {
        Write-Warning -Message "No PowerShell files found under [$CodeCoverageFolder] to analyse for code coverage."
    }
}
elseif ($CodeCoverageOutputFile -and (Get-Module Pester).Version -lt '4.0.4') {
    Write-Warning -Message "Code coverage output not supported on Pester versions before 4.0.4."
}

$result = Invoke-Pester @Parameters

if ($result.failedCount -ne 0) {
    Write-Error "Pester returned errors"
}
