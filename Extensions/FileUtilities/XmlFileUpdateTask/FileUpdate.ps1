##-----------------------------------------------------------------------
## <copyright file="FileUpdate.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Edits and XML file

# Enable -Verbose option
[CmdletBinding()]
param
(
    $filename,
    $xpath,
    $attribute,
    $value 
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

if (test-path -Path $filename)
{
    $xml = [xml](get-content -Path $filename)
    $xml.SelectSingleNode($xpath).$attribute = $value
    $xml.Save($filename)
    write-verbose -Verbose "Updated the file $filename with the new value $xpath/$attribute=$value"
} else
{
    write-error "Cannot find file $filename"
} 