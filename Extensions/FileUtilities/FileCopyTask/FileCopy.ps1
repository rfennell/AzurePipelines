##-----------------------------------------------------------------------
## <copyright file="FileCopy.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Copies files between two locations

# Enable -Verbose option
[CmdletBinding()]
param
(
)

$sourceFolder = Get-VstsInput -Name "sourceFolder"
$targetFolder = Get-VstsInput -Name "targetFolder"
$filter = Get-VstsInput -Name "filter"
$includeInput = Get-VstsInput -Name "includeInput"


$include = $includeInput -split ","
$paths = $sourceFolder -split ","

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Source [$sourceFolder]"
Write-Verbose "Target [$targetFolder]"
Write-Verbose "FileTypes [$include]"
Write-Verbose "Filtering on [$filter]"

if((test-path($targetFolder)) -ne $true)
{
    write-verbose "Creating the folder [$targetFolder]"
    New-Item $targetFolder -Force -ItemType directory
}


Get-ChildItem -Path $paths -Recurse -Include $include -Filter $filter| Copy-Item  -Destination $targetFolder -Force -Verbose
