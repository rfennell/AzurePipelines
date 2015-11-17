##-----------------------------------------------------------------------
## <copyright file="ApplyVersionToVSIX.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number. 
# If found use the first two fields to version the VSIX.
# This is based on the same versioning model to the assemblies https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
#
# For example, if the 'Build number format' build process parameter 
# $(Build.DefinitionName)_$(Major).$(Minor).$(Year:yy)$(DayOfYear).$(rev:r)
# then your build numbers come out like this:
# "Build HelloWorld_1.2.15019.1"
# This script would then apply version 1.2 to your VSIX.

# Enable -Verbose option
[CmdletBinding()]

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

# Regular expression pattern to find the version in the build number 
# and then apply it to the assemblies
$VersionRegex = "\d+\.\d+\.\d+\.\d+"

# test data
#$Env:BUILD_SOURCESDIRECTORY = "C:\projects\github\ParametersXmlAddin\ParametersXmlAddin"
#$Env:BUILD_BUILDNUMBER = "ParametersXmlAddin.Master_1.2.15313.5"

# If this script is not running on a build server, remind user to 
# set environment variables so that this script can be debugged
if(-not ($Env:BUILD_SOURCESDIRECTORY -and $Env:BUILD_BUILDNUMBER))
{
    Write-Error "You must set the following environment variables"
    Write-Error "to test this script interactively."
    Write-Host '$Env:BUILD_SOURCESDIRECTORY - For example, enter something like:'
    Write-Host '$Env:BUILD_SOURCESDIRECTORY = "C:\code\FabrikamTFVC\HelloWorld"'
    Write-Host '$Env:BUILD_BUILDNUMBER - For example, enter something like:'
    Write-Host '$Env:BUILD_BUILDNUMBER = "Build HelloWorld_00.00.00000.0"'
    exit 1
}

# Make sure path to source code directory is available
if (-not $Env:BUILD_SOURCESDIRECTORY)
{
    Write-Error ("BUILD_SOURCESDIRECTORY environment variable is missing.")
    exit 1
}
elseif (-not (Test-Path $Env:BUILD_SOURCESDIRECTORY))
{
    Write-Error "BUILD_SOURCESDIRECTORY does not exist: $Env:BUILD_SOURCESDIRECTORY"
    exit 1
}
Write-Verbose "BUILD_SOURCESDIRECTORY: $Env:BUILD_SOURCESDIRECTORY"

# Make sure there is a build number
if (-not $Env:BUILD_BUILDNUMBER)
{
    Write-Error ("BUILD_BUILDNUMBER environment variable is missing.")
    exit 1
}
Write-Verbose "BUILD_BUILDNUMBER: $Env:BUILD_BUILDNUMBER"

# Get and validate the version data
$VersionData = [regex]::matches($Env:BUILD_BUILDNUMBER,$VersionRegex)
switch($VersionData.Count)
{
   0        
      { 
         Write-Error "Could not find version number data in BUILD_BUILDNUMBER."
         exit 1
      }
   1 {}
   default 
      { 
         Write-Warning "Found more than instance of version data in BUILD_BUILDNUMBER." 
         Write-Warning "Will assume first instance is version."
      }
}

# we only want the first two blocks
$NewVersion = [String]::Format("{0}.{1}", $VersionData[0].Value.Split(".")[0], $VersionData[0].Value.Split(".")[1])

Write-Verbose "Version: $NewVersion"

# Apply the version to the assembly property files
$files = gci $Env:BUILD_SOURCESDIRECTORY -recurse -include "source.extension.vsixmanifest" 
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        $xml = [xml](Get-Content($file))
        attrib $file -r

        $node = $xml.PackageManifest.Metadata.Identity
        $node.Version = $NewVersion

        $xml.Save($file)
        Write-Verbose "$file - version applied"
    }
}
else
{
    Write-Warning "Found no files."
}