[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateScript({
        Test-Path $_
    })]
    [string]$scriptFolder,

    [Parameter(Mandatory)]
    [ValidateScript({
        (Test-Path (Split-Path $_ -Parent)) -and ($_.split('.')[-1] -eq 'xml')
    })]
    [string]$resultsFile,

    [string]$run32Bit,

    [string]$pesterVersion,

    [validateScript({
        If ($_ -eq $Null -or $_ -eq "") {
             # optional value not passed
             $true
        } else
        {
            if (Test-Path $_)
            {
                if (Get-ChildItem -Path $_ -Filter Pester.psd1)
                {
                    $true
                }
                else
                {
                    Throw "Pester.psd1 not found at path specified"
                }
            }
            else 
            {
                Throw "Invalid path for ModuleFolder"
            }
        }
       
    })]
    [string]$moduleFolder,

    [string[]]$Tag,

    [String[]]$ExcludeTag
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

if ([string]::IsNullOrEmpty($moduleFolder) -and (-not(Get-Module -ListAvailable Pester)))
{
    # we have no module path specified so use the copy we have in this task
    $moduleFolder = "$pwd\$pesterVersion"
    Write-Verbose "Loading Pester module from [$moduleFolder]" -verbose
    Import-Module $moduleFolder\Pester.psd1
}
elseif ($moduleFolder)
{
    Write-Verbose "Loading Pester module from [$moduleFolder]" -verbose
    Import-Module $moduleFolder\Pester.psd1
}
else
{
    Import-Module Pester
}

Write-Verbose "Running Pester from [$scriptFolder] output sent to [$resultsFile]" -verbose
$Parameters = @{
    PassThru = $True
    OutputFile = $resultsFile 
    OutputFormat = 'NUnitXml' 
    Script = $scriptFolder
}

if ($Tag)
{
    $Tag = $Tag.Split(',').Replace('"','').Replace("'","")
    $Parameters.Add('Tag',$Tag)
}
if ($ExcludeTag)
{
    $ExcludeTag = $ExcludeTag.Split(',').Replace('"','').Replace("'","")
    $Parameters.Add('ExcludeTag',$ExcludeTag)
}

$result = Invoke-Pester @Parameters

if ($result.failedCount -ne 0)
{ 
    Write-Error "Pester returned errors"
}
