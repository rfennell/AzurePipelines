##-----------------------------------------------------------------------
## <copyright file="ApplyVersionToAssemblies.ps1">(c) Microsoft Corporation. This source is subject to the Microsoft Permissive License. See http://www.microsoft.com/resources/sharedsource/licensingbasics/sharedsourcelicenses.mspx. All other rights reserved.</copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number.
# If found use it to version the assemblies.
#
# For example, if the 'Build number format' build process parameter
# $(BuildDefinitionName)_$(Year:yyyy).$(Month).$(DayOfMonth)$(Rev:.r)
# then your build numbers come out like this:
# "Build HelloWorld_2013.07.19.1"
# This script would then apply version 2013.07.19.1 to your assemblies.

# Enable -Verbose option
[CmdletBinding()]
param (
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

# use the new API to set the variables
$Path = Get-VstsInput -Name "Path"
$VersionNumber = Get-VstsInput -Name "VersionNumber"
$InjectVersion = Get-VstsInput -Name "InjectVersion"
$VersionRegex = Get-VstsInput -Name "VersionRegex"
$outputversion = Get-VstsInput -Name "outputversion"
$Field = Get-VstsInput -Name "Field"
$FilenamePattern = Get-VstsInput -Name "FilenamePattern"


# Make sure path to source code directory is available
if (-not (Test-Path $Path))
{
    Write-Error "Source directory does not exist: $Path"
    exit 1
}
Write-Verbose "Source Directory: $Path"
Write-Verbose "Filename Pattern: $FilenamePattern"
Write-Verbose "Version Number/Build Number: $VersionNumber"
Write-Verbose "Version Filter to extract build number: $VersionRegex"
Write-Verbose "Field to update (all if empty): $Field"
Write-Verbose "Inject Version: $InjectVersion"
Write-verbose "Output: Version Number Parameter Name: $outputversion"



#dot source function for getting the file encoding.
. .\Get-FileEncoding.ps1

if ([System.Convert]::ToBoolean($InjectVersion) -eq $true) {
    Write-Verbose "Using the version number directly"
    $NewVersion = $VersionNumber
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
    $NewVersion = $VersionData[0]
}
Write-Verbose "Extracted Version: $NewVersion"

# Apply the version to the assembly property files
$files = Get-ChildItem $Path -recurse -include $FilenamePattern
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        $FileEncoding = Get-FileEncoding -Path $File.FullName
        $filecontent = Get-Content -Path $file.Fullname
        attrib $file -r
        if ([string]::IsNullOrEmpty($field))
        {
            Write-Verbose "Updating all version fields"
            $filecontent -replace $VersionRegex, $NewVersion | Out-File $file -Encoding $FileEncoding
        } else {
            Write-Verbose "Updating only the '$field' version"
            $filecontent -replace "$field\(`"$VersionRegex", "$field(`"$NewVersion" | Out-File $file -Encoding $FileEncoding
        }

        Write-Verbose "$file - version applied"
    }
    Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
    Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
}
else
{
    Write-Warning "Found no files."
}
