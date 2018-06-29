<#
.Synopsis
    Updates the version of a specified PowerShell module file.
.DESCRIPTION
    This script will update the version number of a specifed PowerShell module file (psd1) using the Configuration module.
    Catches any errors that occur on the versioning section and uses Write-Warning to output what went wrong,
    this is to prevent the whole build failing because it can't version some files which haven't been versioned perviously.

.PARAMETER Path
    Path to the folder holding the module (psd1) files

.PARAMETER VersionNumber
    Version Number to update each module with, must be a string format but will be handled by PS into correct Version object.

.EXAMPLE
    Update-PowerShellModuleVersion.ps1 -Path C:\MyModule -VersionNumber 1.3.53

    This will get each psd1 file within the C:\MyModule and apply version 1.3.53 to it
#>
[cmdletbinding()]
param (

    [Parameter(Mandatory)]
    [String]$Path,

    [Parameter(Mandatory)]
    [string]$VersionNumber,

    [string]$OutputVersion

)

try {
    Write-Verbose -Message "Validating version number - $VersionNumber"
    $null = [Version]::Parse($VersionNumber)
}
catch {
    Write-Error -Message "Invalid version number format. Please check the supplied number and try again"
    exit 1
}

Write-Verbose -Message "Loading Configuration module for applying the version number"
if (Get-Module -Name PowerShellGet -ListAvailable) {
    try {
        Write-Verbose -Message "Attempting to use already configured NuGet provider"
        $null = Get-PackageProvider -Name NuGet -ErrorAction Stop
    }
    catch {
        Write-Verbose -Message "No NuGet provider found, installing it first"
        Install-PackageProvider -Name Nuget -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false
    }

    Write-Verbose -Message "Finding the latest version of the Configuration module on the PSGallery"
    $NewestPester = Find-Module -Name Configuration -Repository PSGallery
    If (-not(Get-Module Configuration) -or (Get-Module Configuration -ListAvailable | Sort-Object Version -Descending| Select-Object -First 1).Version -lt $NewestPester.Version) {
        Write-Verbose -Message "Newer version of the module is available online, installing as current user"
        Install-Module -Name Configuration -Scope CurrentUser -Force -Repository PSGallery
        Import-Module Configuration -force
        $Null = Get-Command -Module Configuration
    }
}
else {
    Write-Verbose -Message "PowerShellGet is unavailable, using Configuration module shipped with task instead"
    Import-Module "$PSScriptRoot\1.3.0\Configuration.psd1" -force
    $Null = Get-Command -Module Configuration
}

Write-Verbose -Message "Finding all the module psd1 files in the specified path"
$ModuleFiles = Get-ChildItem -Path $Path -Filter *.psd1 -Recurse |
    Select-String -Pattern 'RootModule' |
    Select-Object -ExpandProperty Path -Unique

Write-Verbose "Found $($ModuleFiles.Count) modules. Beginning to apply updated version number $VersionNumber."

Foreach ($Module in $ModuleFiles)
{
    Write-Verbose -Message "Updating version for $($Module.split('\')[-1]) at path $Module"
    Update-Metadata -Path $Module -PropertyName ModuleVersion -Value $VersionNumber
}
Write-Verbose "Set the output variable '$outputversion' with the value $VersionNumber"
Write-Host "##vso[task.setvariable variable=$outputversion;]$VersionNumber"
