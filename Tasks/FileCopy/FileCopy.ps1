##-----------------------------------------------------------------------
## <copyright file="FileCopy.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Copies files between two locations

# Enable -Verbose option
[CmdletBinding()]
param
(
    $source,
    $target,
    $match

)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Source [$source]"
Write-Verbose "Target [$target]"
Write-Verbose "Match [$match]"

if((test-path($target)) -ne $true)
{
    write-verbose "Creating the folder [$target]"
    New-Item $target -Force -ItemType directory
}
Get-ChildItem -Filter $match -Path $source -Recurse | Copy-Item  -Destination $target -Force -Verbose
