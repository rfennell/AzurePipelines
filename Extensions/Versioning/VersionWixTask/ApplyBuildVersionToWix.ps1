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

[CmdletBinding()]
# Enable -Verbose option
param (
   [String]$Path,
   [String]$File,
   [string]$VersionNumber,
   [string]$VersionRegex,
   $outputversion
)

function ReplaceVersion {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        $contents,
        $name,
        $value
    )

    # regex for a single digit replace
    $regex = "<\?define\s+{0}\s+=\s+\""\d+\""\s+\?>"
    if ([regex]::IsMatch($value , "\d+\.\d+\.\d+\.\d+"))
    {
        # we need to handle a full version
        $regex = "<\?define\s+{0}\s+=\s+\""\d+\.\d+\.\d+\.\d+\""\s+\?>"
    }

    return $contents -replace  [string]::Format($regex, $name),  [string]::Format("<?define {0} = ""{1}"" ?>", $name, $value)
}


# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

# Make sure path to source code directory is available
if (-not (Test-Path $Path))
{
    Write-Error "Source directory does not exist: $Path"
    exit 1
}
Write-Verbose "Source Directory: $Path"
Write-Verbose "Target File $file"
Write-Verbose "Version Number/Build Number: $VersionNumber"
Write-Verbose "Version Filter: $VersionRegex"
Write-verbose "Output: Version Number Parameter Name: $outputversion"

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
# AppX will not allow leading zeros, so we strip them out
$extracted = [string]$VersionData[0]
$parts = $extracted.Split(".")

if ($parts.Count -ne 4)
{
    Write-Error "Could not find the expected 4 parts in version number data in $VersionNumber."
    exit 1
}

$versionData = @{MajorVersion = [int]$parts[0]; MinorVersion = [int]$parts[1];BuildNumber = [int]$parts[2];Revision = [int]$parts[3];FullVersion =  [string]::Format("{0}.{1}.{2}.{3}" ,[int]$parts[0],[int]$parts[1],[int]$parts[2],[int]$parts[3])}

Write-Verbose "Version: $NewVersion"

# Apply the version to the assembly property files
$files = gci $path -recurse -include $file 
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        # I would like to treat this an XML file, but can't see to handle the XmlProcessingInstructions, so using simple replace
        $fileContents = Get-Content -path $file -raw
        attrib $file -r

        foreach ($key in $VersionData.Keys)
        {
            $fileContents = $fileContents | ReplaceVersion -name $key -value $VersionData.$key
        }
    
        $fileContents | Set-Content($file)
        Write-Verbose "$file - version applied"
    }
    Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
    Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
}
else
{
    Write-Warning "Found no files."
}


