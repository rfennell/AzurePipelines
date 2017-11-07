param
(
    $buildmode,
    $variable,
    $mode,
    $value,
    $usedefaultcreds

 )


function Set-BuildDefinationVariable
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID,
        $data,
        $usedefaultcreds

    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds

    write-verbose "Updating Build Definition $builddefID for $($tfsUri)/$($teamproject)"

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=4.0"
    $jsondata = $data | ConvertTo-Json -Compress -Depth 10 #else we don't get lower level items

    $response = $webclient.UploadString($uri,"PUT", $jsondata)
    $response

}

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


function Get-BuildDefination
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID,
        $usedefaultcreds
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds

    write-verbose "Getting Build Definition $builddefID "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=4.0"

    $response = $webclient.DownloadString($uri) | ConvertFrom-Json
    $response

}



function Update-Build
{
    Param(
        $tfsuri,
        $teamproject,
        $builddefid,
        $mode,
        $variable,
        $value,
        $usedefaultcreds
      )
    # get the old definition
    $def = Get-BuildDefination -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid -usedefaultcreds $usedefaultcreds
    Write-Verbose "Current value of variable [$variable] is [$($def.variables.$variable.value)]"
    # make the change
    if ($mode -eq "Manual")
    {
        Write-Verbose "Manually updating variable"
        $def.variables.$variable.value = "$value"
    } else
    {
        Write-Verbose "Autoincrementing variable"
        $def.variables.$variable.value = "$([convert]::ToInt32($def.variables.$variable.value) +1)"
    }
    Write-Verbose "Setting variable [$variable] to value [$($def.variables.$variable.value)]"
    # write it back
    $response = Set-BuildDefinationVariable -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid -data $def -usedefaultcreds $usedefaultcreds

}

function Get-BuildsDefsForRelease
{
    param
    (
        $tfsuri,
        $teamproject,
        $releaseID,
        $usedefaultcreds
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds

    write-verbose "Getting Builds for Release releaseID"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up
	$rmtfsUri = $tfsUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseId)?api-version=3.0-preview"
    $response = $webclient.DownloadString($uri)

    $data = $response | ConvertFrom-Json

    $return = @()
    $data.artifacts.Where({$_.type -eq "Build"}).ForEach( {
        Write-Verbose "Getting DefintionID for build instance $($_.definitionReference.version.id)"
        $return += $_.definitionReference.definition.id
    })

    $return

}

function Get-Build
{

    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $usedefaultcreds
    )

    write-verbose "Getting BuildDef for Build"

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)?api-version=4.0"
    $jsondata = $webclient.DownloadString($uri) | ConvertFrom-Json
    $jsondata
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$builddefid = $env:BUILD_DEFINITIONID
$buildid = $env:BUILD_BUILDID

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "builddefid = [$env:BUILD_DEFINITIONID]"
Write-Verbose "buildid = [$env:BUILD_BUILDID]"
Write-Verbose "usedefaultcreds = $usedefaultcreds"

if ( [string]::IsNullOrEmpty($releaseid))
{
    Write-Verbose "Running inside a build so updating current build $buildid"
    $build = Get-Build -tfsuri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds

    $builddefid = $build.definition.id
    Write-Verbose "Build has definition id of $builddefid"

    Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $builddefid -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds

} else {

    Write-Verbose "Running inside a release so updating asking which build(s) to update"
    Write-Verbose "Mode is $buildmode"
    if ($buildmode -eq "AllArtifacts")
    {
        $builddefs = Get-BuildsDefsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds
        foreach($id in $builddefs)
        {
            Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $id -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds
        }
    } else
    {
        Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $builddefid -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds
    }
}

