$VerbosePreference ='Continue' # equiv to -verbose

function Update-ParametersFile
{
    param
    (
        $paramFilePath,
        $paramsToReplace
    )

    write-verbose "Updating parameters file '$paramFilePath'" -verbose
    $content = get-content $paramFilePath
	$paramsToReplace.GetEnumerator() | % {
        Write-Verbose "Replacing value for key '$($_.Name)'" -Verbose
	    $content = $content.Replace($_.Name, $_.Value)
    }
    set-content -Path $paramFilePath -Value $content

}

# the script folder
$folder = Split-Path -parent $MyInvocation.MyCommand.Definition
write-verbose "Deploying Website '$package' using script in '$folder'" 

# work out the variables to replace using a naming convention
$parameters = @(Get-Variable -include "__*__") 
write-verbose "Discovered replacement parameters that match the convention '__*__': $($parameters | Out-string)" 
Update-ParametersFile -paramFilePath "$ApplicationPath\$packagePath\$package.SetParameters.xml" -paramsToReplace $parameters

write-verbose "Calling '$ApplicationPath\$packagePath\$package.deploy.cmd'" 
& "$ApplicationPath\$packagePath\$package.deploy.cmd" /Y  /m:"$PublishUrl" -allowUntrusted /u:"$PublishUser" /p:"$PublishPassword" /a:Basic | Write-Verbose 