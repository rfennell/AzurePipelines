##-----------------------------------------------------------------------
## <copyright file="ApplyVersionToVSIX.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number. 
# If found uses either the all the version number or first two fields to version the VSIX.
# This is based on the same versioning model to the assemblies https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
#
# For example, if the 'Build number format' build process parameter 
# $(Build.DefinitionName)_$(Major).$(Minor).$(Year:yy)$(DayOfYear).$(rev:r)
# then your build numbers come out like this:
# "Build HelloWorld_1.2.15019.1"
# This script would then apply version 1.2.15019.1 or 1.2 to your VSIX.

# Enable -Verbose option
[CmdletBinding()]
param (
)


# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

# use the new API to set the variables
$Path = Get-VstsInput -Name "Path"
$VersionNumber = Get-VstsInput -Name "VersionNumber"
$UseRegex = Get-VstsInput -Name "UseRegex"
$DigitMode = Get-VstsInput -Name "DigitMode"
$VersionRegex = Get-VstsInput -Name "VersionRegex"
$outputversion = Get-VstsInput -Name "outputversion"


# Make sure path to source code directory is available
if (-not (Test-Path $Path))
{
    Write-Error "Source directory does not exist: $Path"
    exit 1
}
Write-Verbose "Source Directory: $Path"
Write-Verbose "Version Number/Build Number: $VersionNumber"
Write-Verbose "Version Filter: $VersionRegex"
Write-verbose "Output: Version Number Parameter Name: $outputversion"

if ([System.Convert]::ToBoolean($UseRegex) -eq $true) 
{
    Write-Verbose "Processing provided version number with regex"
    # Get and validate the version data
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

    if ($DigitMode -eq 'All')
    {
        $NewVersion = $VersionData[0]

    } else 
    {
        # we only want the first two blocks
        Write-Verbose "Limited discovered version number to first two digits"
        $parts = $VersionData[0].Value.Split(".")
        $NewVersion = [String]::Format("{0}.{1}", $parts[0], $parts[1])
    }
} else {
    Write-Verbose "Using provided version number without reformating"
    $NewVersion = $VersionNumber
}

Write-Verbose "Version: $NewVersion"

# Apply the version to the assembly property files
$files = gci $path -recurse -include "source.extension.vsixmanifest" 
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        $xml = [xml](Get-Content($file))
        attrib $file -r

        $node = $xml.PackageManifest.Metadata.Identity
        $node.Version = [string]$NewVersion

        $xml.Save($file)
        Write-Verbose "$file - version applied"
    }
    Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
    Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"

}
else
{
    Write-Warning "Found no files."
}