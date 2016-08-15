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
    $value,
    $recurse
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose
# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Param: filename - $filename"
Write-Verbose "Param: recurse - $recurse"
Write-Verbose "Param: xpath - $xpath"
Write-Verbose "Param: attribute - $attribute"
Write-Verbose "Param: value - $value"

$convertedFlag = [System.Convert]::ToBoolean($recurse)

$files = Get-ChildItem -Path $filename -Recurse:$convertedFlag

foreach ($file in $files)
{
    if (test-path -Path $file)
    {
        $xml = [xml](get-content -Path $file)
        if ([String]::IsNullOrEmpty($attribute))
        {
            $xml.SelectSingleNode($xpath).InnerText = $value
            write-verbose -Verbose "Updated the file $file with the new value $xpath.InnerText=$value"
        } else
        {
            $xml.SelectSingleNode($xpath).$attribute = $value
            write-verbose -Verbose "Updated the file $file with the new value $xpath.$attribute=$value"
        }
        $xml.Save($file)
    
    } else
    {
        write-error "Cannot find file $file"
    } 
}

