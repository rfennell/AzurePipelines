##-----------------------------------------------------------------------
## <copyright file="ApplyVersionToVSIX.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number. 
# This is based on the same versioning model to the assemblies https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
#
# For example, if the 'Build number format' build process parameter 
# $(Build.DefinitionName)_$(Major).$(Minor).$(Year:yy)$(DayOfYear).$(rev:r)
# then your build numbers come out like this:
# "Build HelloWorld_1.2.15019.1"
# This script would then apply version 1.2.15019.1 to your VSIX.

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


# Make sure path to source code directory is available
if (-not (Test-Path $Path))
{
    Write-Error "Source directory does not exist: $Path"
    exit 1
}
Write-Verbose "Source Directory: $Path"
Write-Verbose "Version Number/Build Number: $VersionNumber"
Write-Verbose "Version Filter: $VersionRegex"
Write-Verbose "Inject Version: $InjectVersion"
Write-verbose "Output: Version Number Parameter Name: $outputversion"

# Get and validate the version data
if ([System.Convert]::ToBoolean($InjectVersion) -eq $true) {
    Write-Verbose "Using the version number directly"
    $NewVersion = $VersionNumber
} else {
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
    # AppX will not allow leading zeros, so we strip them out
    $extracted = [string]$VersionData[0]
    $parts = $extracted.Split(".")
    $NewVersion =  [string]::Format("{0}.{1}.{2}.{3}" ,[int]$parts[0],[int]$parts[1],[int]$parts[2],[int]$parts[3])
}

Write-Verbose "Version: $NewVersion"

# Apply the version to the assembly property files
$files = gci $path -recurse -include "AppManifest.xml" 
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        $xml = [xml](Get-Content($file))
        attrib $file -r

        $node = $xml.App
        $node.Version = $NewVersion.ToString()

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
