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
)

# use the new API to set the variables
$Path = Get-VstsInput -Name "Path"
$VersionNumber = Get-VstsInput -Name "VersionNumber"
$InjectVersion = Get-VstsInput -Name "InjectVersion"
$VersionRegex = Get-VstsInput -Name "VersionRegex"
$outputversion = Get-VstsInput -Name "outputversion"


# Get and validate the version data
if ([System.Convert]::ToBoolean($InjectVersion) -eq $true) {
    Write-Verbose "Using the version number directly"
    # First the old check
    try {
        Write-Verbose -Message "Validating version number - $VersionNumber"
        $null = [Version]::Parse($VersionNumber)
    }
    catch {
        Write-Error -Message "Invalid version number format. Please check the supplied number and try again"
        exit 1
    }
} else {
    Write-Verbose "Extracting version number from build number"
    $VersionData = [regex]::matches($VersionNumber,$VersionRegex)

    switch($VersionData.Count)
    {
    0
        {
            Write-Error "Could not find version number data in $VersionNumber."
            exit 1
        }
    1 {}
    default
        {
            Write-Warning "Found more than instance of version data in $VersionNumber."
            Write-Warning "Will assume first instance is version."
        }
    }
    $VersionNumber = $VersionData[0]
}

Write-Verbose -Message "Loading Configuration module for applying the version number"
if (Get-Module -Name PowerShellGet -ListAvailable) {
    try {
        Write-Verbose -Message "Attempting to use already configured NuGet provider"
        $null = Get-PackageProvider -Name NuGet -ErrorAction Stop
    }
    catch {
        try {
            Write-Verbose -Message "No NuGet provider found, installing it first"
            Install-PackageProvider -Name Nuget -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Host "##vos[task.logissue type=warning]Falling back to version of Configuration shipped with extension. To use a newer version please update the version of PowerShellGet available on this machine."
            Import-Module "$PSScriptRoot\1.3.0\Configuration.psd1" -force
        }
    }

    Write-Verbose -Message "Finding the latest version of the Configuration module on the PSGallery"
    $NewestConfiguration = Find-Module -Name Configuration | Sort-Object Version -Descending | Select-Object -First 1
    If (-not(Get-Module Configuration) -or (Get-Module Configuration -ListAvailable | Sort-Object Version -Descending| Select-Object -First 1).Version -lt $NewestConfiguration.Version) {
        Write-Verbose -Message "Newer version of the module is available online, installing as current user"
        Install-Module -Name Configuration -Scope CurrentUser -Force -Repository $NewestConfiguration.Repository
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
