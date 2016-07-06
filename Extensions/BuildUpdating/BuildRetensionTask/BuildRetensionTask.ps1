Param(
    mode
    )

function Set-BuildRetension
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildID,
        $keepForever
    )

    $webclient = Get-WebClient
    
    write-verbose "Setting BuildID $buildID with retension set to $keepForever"

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildID)?api-version=2.0"
    $data = @{keepForever = $keepForever} | ConvertTo-Json
    $response = $webclient.UploadString($uri,"PATCH", $data) 
    
}

function Get-BuildsForRelease
{
    param
    (
        $tfsuri,
        $teamproject,
        $releaseID
    )

    $webclient = Get-WebClient
    
    write-verbose "Getting Builds for Release releaseID"

    $uri = "$($tfsUri)/$($teamproject)/_apis/release/releases/$($releaseId)?api-version=3.0-preview"
    $response = $webclient.DownloadString($uri)

    $data = $response | ConvertFrom-Json

    $return = @{}
    $data.artifacts.Where({$_.type -eq "Build"}).ForEach( {
        $return += $_.definitionReference.version.id
    })

    $return

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

if ($mode -eq "AllArtifacts")
{
    $builds = Get-BuildsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid
    foreach($id in $builds)
    {
        Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $id -keepForever $true
    }
} else 
{
    Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -keepForever $true
}