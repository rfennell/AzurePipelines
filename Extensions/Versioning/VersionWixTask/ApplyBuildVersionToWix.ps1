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
)

# use the new API to set the variables
$Path = Get-VstsInput -Name "Path"
$File = Get-VstsInput -Name "File"
$VersionNumber = Get-VstsInput -Name "VersionNumber"
$InjectVersion = Get-VstsInput -Name "InjectVersion"
$VersionRegex = Get-VstsInput -Name "VersionRegex"
$outputversion = Get-VstsInput -Name "outputversion"
$fieldsToMatch = Get-VstsInput -Name "FieldsToMatch"

function ReplaceVersion {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        $contents,
        $name,
        $value
    )

    # regex for a single digit replace
    $regex = "<\?define\s+{0}\s*=\s*\""\d+\""\s+\?>"
    if ([regex]::IsMatch($value , "\d+\.\d+\.\d+\.\d+"))
    {
        # we need to handle a full version
        $regex = "<\?define\s+{0}\s*=\s*\""\d+\.\d+\.\d+\.\d+\""\s+\?>"
    }

    Write-Verbose "   updating value for $name with $value"
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
Write-Verbose "Inject Version: $InjectVersion"
Write-Verbose "Version Filter: $VersionRegex"
Write-Verbose "Fields to Match: $fieldsToMatch"
Write-verbose "Output: Version Number Parameter Name: $outputversion"


# validate we have the field names
if ([String]::IsNullOrEmpty($fieldsToMatch)) {
     Write-Error "No fields to match provided, expecting 5 part comma separated list."
     exit 1
} else {
    $fieldNames = $fieldsToMatch.Split(",");
    if ($fieldNames.Count -ne 5) {
         Write-Error "Wrong number of fields to match provided, expecting 5 part comma separated list."
         exit 1
    }
}

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
    $NewVersion = [string]$VersionData[0]
    $parts = $NewVersion.Split(".")

    if ($parts.Count -ne 4)
    {
        Write-Error "Could not find the expected 4 parts in version number data in $VersionNumber."
        exit 1
    }

    $versionData = @{$fieldNames[0] = [int]$parts[0]; $fieldNames[1] = [int]$parts[1];$fieldNames[2] = [int]$parts[2];$fieldNames[3] = [int]$parts[3];$fieldNames[4] =  [string]::Format("{0}.{1}.{2}.{3}" ,[int]$parts[0],[int]$parts[1],[int]$parts[2],[int]$parts[3])}
}
Write-Verbose "Will use the version: $NewVersion"


# Apply the version to the assembly property files
$files = gci $path -recurse -include $file 
if($files)
{
    Write-Verbose "Will apply $NewVersion to $($files.count) files."

    foreach ($file in $files) {
        # I would like to treat this an XML file, but can't see to handle the XmlProcessingInstructions, so using simple replace
        Write-Verbose "$file - applying version"
        $fileContents = Get-Content -path $file -raw
        attrib $file -r

        foreach ($key in $VersionData.Keys)
        {
            $fileContents = $fileContents | ReplaceVersion -name $key -value $VersionData.$key
        }
    
        $fileContents | Set-Content($file)
    }
    Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
    Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
}
else
{
    Write-Warning "Found no files."
}


