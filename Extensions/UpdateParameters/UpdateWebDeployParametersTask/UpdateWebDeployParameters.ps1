##-----------------------------------------------------------------------
## <copyright file="UpdateWebDeployParameters.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Replaces the contents of a MS WebDeploy setparameters.xml file with values
# read from environmental variable, usually set as part of the VSTS/TFS release
# management pipeline.
#
# A naming convension is used to match the variables and the file entries 
# 
# For example, the value to set is stored in a variable __MYVAR__

# Enable -Verbose option
[CmdletBinding()]
param (

    # The name of the webdeploy package
    [Parameter(Mandatory)]
    [string]$Package,
    
    # The folder the web deploy package is stored in
    [Parameter(Mandatory)]
    [string]$Basepath,
    
    # Pattern to match 
    [Parameter(Mandatory)]
    [string]$Match 
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

function Update-ParametersFile
{
    param
    (
        $paramFilePath,
        $paramsToReplace
    )

    if (Test-Path $paramFilePath)
    {
        write-verbose "Updating parameters file '$paramFilePath'" 
    
        [string]$content = get-content $paramFilePath
  	    $paramsToReplace.GetEnumerator() | ForEach-Object {
          Write-Verbose "Replacing value for key '$($_.Name)'"
	      $content = $content -replace $_.Name, $_.Value
        }
        set-content -Path $paramFilePath -Value $content
    } else
    {
        Write-Warning  "Cannot find parameters file '$paramFilePath'" 
    }
}

write-verbose "Using token '$Match' to find evironment variables" 

# work out the variables to replace using a naming convention
$parameters = @(Get-ChildItem -Path env:$Match) 
write-verbose "Discovered replacement parameters that match the convention '__*__': $($parameters | Out-string)" 
Update-ParametersFile -paramFilePath "$Basepath\$Package.SetParameters.xml" -paramsToReplace $parameters
