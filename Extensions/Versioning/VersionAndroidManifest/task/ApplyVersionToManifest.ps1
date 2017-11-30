[cmdletbinding()]
param (
    [parameter(Mandatory)]
    [ValidateScript({
        If (Test-Path $_){
            $True
        }
        else {
            Write-Error "Path is invalid. Please check and confirm $_ exists."
            $false
        }
    })]
    [string]$Path,

    [Parameter(Mandatory)]
    [String]$VersionNumber,

    [Parameter(Mandatory)]
    [String]$VersionNameFormat,

    [Parameter(Mandatory)]
    [string]$VersionCodeFormat,

    [string]$VersionRegex,

    [string]$FilenamePattern = 'AndroidManifest.xml',

    [string]$OutputVersion
)
$VerbosePreference = 'Continue'
Write-Verbose -Message "Source Directory: $Path"
Write-Verbose -Message "Filename Pattern: $FilenamePattern"
Write-Verbose -Message "Version : $VersionNumber"
Write-Verbose -Message "Version Filter to extract build number: $VersionRegex"
Write-Verbose -Message "Version format to use for versionName: $VersionNameFormat"
Write-Verbose -Message "Version format to use for versionCode: $VersionCodeFormat"
Write-verbose -Message "Output: Version Number Parameter Name: $outputversion"

$Files = Get-ChildItem -Path $Path -Include $FilenamePattern -Recurse -File
Write-Verbose -Message "Found $($Files.count) to update."

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
$NewVersion = $VersionData[0].value
Write-Verbose "Extracted Version: $NewVersion"

$VersionName = Get-VersionName -Format $VersionNameFormat -Version $NewVersion
Write-Verbose -Message "Version Name will be: $VersionName"

$VersionCode = Get-VersionCode -Format $VersionCodeFormat -Version $NewVersion
Write-Verbose -Message "Version Code will be $VersionCode"

foreach ($File in $Files) {
    Write-Verbose -Message "Updating $($File.Fullname)"
    Update-ManifestFile -filename $File.Fullname -versioncode $VersionCode -versionname $VersionName
    Write-Verbose -Message "Set version numbers."
}

Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
