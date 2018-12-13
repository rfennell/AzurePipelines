param
(
    $builddefinitionname,
    $variable,
    $localVariable,
    $usedefaultcreds
 )

function Get-WebClient
{
    param
    (
       $usedefaultcreds
    )

    $webclient = new-object System.Net.WebClient

    if ([System.Convert]::ToBoolean($usedefaultcreds) -eq $true)
    {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    } else {
        Write-Verbose "Using SystemVssConnection personal access token"
        $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
        $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
        $webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
    }

    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $webclient.Headers["Content-Type"] = "application/json"
    $webclient

}


function Get-BuildDefinition
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefName,
        $usedefaultcreds
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds

    write-verbose "Getting Build Definition $builddefID "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0"

    $response = $webclient.DownloadString($uri) | ConvertFrom-Json
    $response
    $definition = ($response.value | Where-Object {$_.Name -eq $buildDefName})

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($definition.id)?api-version=4.0"
    $response = $webclient.DownloadString($uri) | ConvertFrom-Json
    $response
}

function Update-CurrentScopeVariable
{
    Param(
        $tfsuri,
        $teamproject,
        $builddefname,
        $variable,
        $localVariable,
        $usedefaultcreds
      )
    # get the old definition
    $def = Get-BuildDefinition -tfsuri $tfsuri -teamproject $teamproject -buildDefName $builddefname -usedefaultcreds $usedefaultcreds

    $foundGroup = $null
    $item = $null
    if ($variable -in $def.variables.PSobject.Properties.Name)
    {
        Write-Verbose "Current value of the pipeline variable [$variable] is [$($def.variables.$variable.value)]"
        $value = "$($def.variables.$variable.value)"
    } else {
        Write-verbose "Variable is not found as a pipeline variable"
        # check if there is a variable group
        foreach ($group in $def.variableGroups)
        {
            Write-verbose "Checking for variable in '$($group.name)'"
            if ($variable -in $group.variables.PSobject.Properties.Name)
            {
                write-verbose "group details $group"
                Write-Verbose "Current value of the variable [$variable] is [$($group.variables.$variable.value)] in [$($group.name)] with ID [$($group.id)]"
                $item =$group.variables.$variable
                $foundGroup = $group
                break
            }  
        }
    }
    Write-Output ("##vso[task.setvariable variable=$localVariable;]$value")
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$builddefid = $env:BUILD_DEFINITIONID

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "builddefid = [$env:BUILD_DEFINITIONID]"
Write-Verbose "usedefaultcreds = $usedefaultcreds"


Write-Verbose ("Getting the variable from specified definition.")
Update-CurrentScopeVariable -tfsuri $collectionUrl -teamproject $teamproject -builddefname $builddefinitionname -variable $variable -localVariable $localVariable -usedefaultcreds $usedefaultcreds

