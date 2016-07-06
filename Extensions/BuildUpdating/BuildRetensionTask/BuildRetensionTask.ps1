function Set-BuildRetension
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildID,
        $keepForever
    )

    $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
    $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
    $webclient = new-object System.Net.WebClient
    $webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $webclient.Headers["Content-Type"] = "application/json"
    
    write-verbose "Setting BuildID $buildID with retension set to $keepForever via $tfsUri "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildID)?api-version=2.0"
    $data = @{keepForever = $keepForever} | ConvertTo-Json
    $response = $webclient.UploadString($uri,"PATCH", $data) 
    
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$buildid = $env:BUILD_BUILDID

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "buildid = [$env:BUILD_BUILDID]"

Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -keepForever $true
