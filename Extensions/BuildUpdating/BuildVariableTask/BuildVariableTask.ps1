param
(
    $variable,
    $autoincrement,
    $value 
 )

function Set-BuildDefinationVariable
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID,
        $data
    )

    $webclient = Get-WebClient
    
    write-verbose "Updating Build Definition $builddefID "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=2.0&revision=$revision"
    $jsondata = $data | ConvertTo-Json -Depth 10 #else we don't get lower level items

    $response = $webclient.UploadString($uri,"PUT", $jsondata) 
    $response
    
}

function Get-WebClient
{

    $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
    $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
    $webclient = new-object System.Net.WebClient
    $webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $webclient.Headers["Content-Type"] = "application/json"

    $webclient

}


function Get-BuildDefination
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID
    )

    $webclient = Get-WebClient
   
    write-verbose "Getting Build Definition $builddefID "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=2.0"

    $response = $webclient.DownloadString($uri) | ConvertFrom-Json 
    $response
    
}


# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$builddefid = $env:BUILD_DEFINITIONID

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "builddefid = [$env:BUILD_DEFINITIONID]"

# get the old definition
$def = Get-BuildDefination -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid

# make the change
if ($autoincrement -eq $true)
{
    $def.variables.$variable.value = "$([convert]::ToInt32($def.variables.$variable.value) +1)"
    Write-Verbose "Auto-incrementing variable [$variable] to value [$($def.variables.$variable.value)]"
} else 
{
    $def.variables.$variable.value = "$value"
    Write-Verbose "Setting variable [$variable] to value [$($def.variables.$variable.value)]"
}


# write it back
$response = Set-BuildDefinationVariable -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid -data $def

