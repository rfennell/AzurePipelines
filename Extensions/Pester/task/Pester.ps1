[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateScript( {
            Test-Path $_
        })]
    [string]$scriptFolder,

    [Parameter(Mandatory)]
    [ValidateScript( {
            (Test-Path (Split-Path $_ -Parent)) -and ($_.split('.')[-1] -eq 'xml')
        })]
    [string]$resultsFile,

    [string]$run32Bit,

    [string]$pesterVersion,

    [validateScript( {
            If ([String]::IsNullOrWhiteSpace($_)) {
                # optional value not passed
                $true
            }
            else {
                if (Test-Path $_) {
                    if (Get-ChildItem -Path $_ -Filter Pester.psd1) {
                        $true
                    }
                    else {
                        Throw "Pester.psd1 not found at path specified"
                    }
                }
                else {
                    Throw "Invalid path for ModuleFolder: $_"
                }
            }

        })]
    [string]$moduleFolder,

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

    [string]$ForceUseOfPesterInTasks
)


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
write-verbose "Running in $($env:Processor_Architecture) PowerShell" -verbose

if (([bool]::Parse($ForceUseOfPesterInTasks) -eq $true) -and $(-not([string]::IsNullOrEmpty($pesterVersion)))) {
    # we have no module path specified and Pester is not installed on the PC
    # have to use a version in this task
    $moduleFolder = "$PSScriptRoot\$pesterVersion"
    Write-Verbose "Loading Pester module from [$moduleFolder] using module PSM shipped in VSTS extension" -verbose
    Import-Module -Name $moduleFolder\Pester.psd1
}
elseif ([string]::IsNullOrEmpty($moduleFolder) -and
    (-not(Get-Module -ListAvailable Pester))) {
    # we have no module path specified and Pester is not installed on the PC
    # have to use a version in this task
    $moduleFolder = "$PSScriptRoot\$pesterVersion"
    Write-Verbose "Loading Pester module from [$moduleFolder] using module PSM shipped in VSTS extension, as not installed on PC" -verbose
    Import-Module $moduleFolder\Pester.psd1
}
elseif ($moduleFolder) {
    Write-Verbose "Loading Pester module from [$moduleFolder] using user specificed overrided location" -verbose
    Import-Module $moduleFolder\Pester.psd1
}
else {
    Write-Verbose "No Pester module location parameters passed, and not forcing use of Pester in task, so using Powershell default module location"
    Import-Module Pester
}

Write-Verbose "Running Pester from [$scriptFolder] output sent to [$resultsFile]" -verbose
$Parameters = @{
    PassThru = $True
    OutputFile = $resultsFile
    OutputFormat = 'NUnitXml'
    Script = $scriptFolder
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
    $Files = Get-ChildItem -Path $scriptFolder -include *.ps1, *.psm1 -Exclude *.Tests.ps1 -Recurse |
        Select-object -ExpandProperty Fullname

    if ($Files) {
        $Parameters.Add('CodeCoverage', $Files)
        $Parameters.Add('CodeCoverageOutputFile', $CodeCoverageOutputFile)
    }
    else {
        Write-Warning -Message "No PowerShell files found under $ScripFolder to analyse for code coverage."
    }
}
elseif ($CodeCoverageOutputFile -and (Get-Module Pester).Version -lt '4.0.4') {
    Write-Warning -Message "Code coverage output not supported on Pester versions before 4.0.4."
}

$result = Invoke-Pester @Parameters

if ($result.failedCount -ne 0) {
    Write-Error "Pester returned errors"
}
