[CmdletBinding()]
param
(
    $collectionUrl,
    $teamproject,
    $builddefid,
    $builddefinitionname,
    $variable,
    $localVariable,
    $usedefaultcreds,
    $token
)
function Get-WebClient
{
    param
    (
       $usedefaultcreds,
       $token
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webclient = new-object System.Net.WebClient

    if ([System.Convert]::ToBoolean($usedefaultcreds) -eq $true)
    {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    } else {
        Write-Verbose "Using SystemVssConnection personal access token"
        $webclient.Headers.Add("Authorization" ,"Bearer $token")
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
        $usedefaultcreds,
        $token
    )
    Write-Verbose "Function: Get-BuildDefinition Parameters"
    Write-Verbose "tfsUri: $tfsuri"
    Write-Verbose "teamProject: $teamproject"
    Write-Verbose "buildDefinitionName: $buildDefName"

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Getting Build Definition $buildDefName "

    $apiVersion = "4.0"
    write-verbose "Checking API version available"
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=$apiVersion"

    try {
        Write-Verbose "Initiating GET Request to URI: $uri"
        $definitionsResponse = $webclient.DownloadString($uri) | ConvertFrom-Json
    } catch {
        # to provide TFS2017 support
        $apiVersion = "2.0"
        Write-Verbose "Legacy: Initiating GET Request to URI: $uri"
        $definitionsResponse = $webclient.DownloadString($uri) | ConvertFrom-Json
    }
    write-verbose "API Version is $apiversion"

    if($null -ne $definitionsResponse){
        $definition = ($definitionsResponse.value | Where-Object {$_.Name -eq $buildDefName})

        if($null -ne $definition ){
            $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($definition.id)?api-version=$apiversion"
            Write-Verbose "Initiating GET Request to URI: $uri"
            $buildResponse = $webclient.DownloadString($uri) | ConvertFrom-Json

            Write-Verbose "DEFINITION RESPONSE: $buildResponse"
            return $buildResponse

        }
        if ($null -eq $definition ) {
            Write-Verbose "Failed to find the specified definition $buildDefName."
        }
    } else {
        Write-Verbose "Failed to retrieve list of build definitions from $tfsuri"
    }
}

function Update-CurrentScopeVariable
{
    Param(
        $tfsuri,
        $teamproject,
        $builddefname,
        $variable,
        $localVariable,
        $usedefaultcreds,
        $token
      )
    # get the old definition
    Write-Verbose "Function: Update-CurrentScopeVariable"
    Write-Verbose "tfsUri: $tfsuri"
    Write-Verbose "teamProject: $teamproject"
    Write-Verbose "buildDefinitionName: $builddefname"
    Write-Verbose "remoteVariable: $variable"
    Write-Verbose "localVariable: $localVariable"
    Write-Verbose "usingDefaultCreds: $usedefaultcreds"

    $def = Get-BuildDefinition -tfsuri $tfsuri -teamproject $teamproject -buildDefName $builddefname -usedefaultcreds $usedefaultcreds -token  $token
    if($null -ne $def)
    {
        Write-Verbose "Found definition $def"
        $foundGroup = $null
        $item = $null
        if ($variable -in $def.variables.PSobject.Properties.Name)
        {
            Write-Verbose "Current value of the pipeline variable [$variable] is [$($def.variables.$variable.value)]"
            $value = "$($def.variables.$variable.value)"
        } if($variable -notin $def.variables.PSobject.Properties.Name) {
            Write-verbose "Variable is not found as a pipeline variable"
            # check if there is a variable group
            foreach ($group in $def.variableGroups)
            {
                Write-verbose "Checking for variable in $($group.name)"
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
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build details
Write-Verbose "collectionUrl = [$collectionUrl]"
# we may have added quotes as we passed through PSCore
$teamproject = $teamproject.Trim("'")
Write-Verbose "teamproject = [$teamproject]"
Write-Verbose "builddefid = [$builddefid]"
Write-Verbose "usedefaultcreds = $usedefaultcreds"

Write-Verbose "builddefinitionname = [$builddefinitionname]"
Write-Verbose "variable = [$variable]"
Write-Verbose "localVariable = [$localVariable]"

Write-Verbose ("Getting the variable from specified definition.")
Update-CurrentScopeVariable -tfsuri $collectionUrl -teamproject $teamproject -builddefname $builddefinitionname -variable $variable -localVariable $localVariable -usedefaultcreds $usedefaultcreds -token $token

