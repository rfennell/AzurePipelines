[CmdletBinding()]
Param(
    $mode,
    $usedefaultcreds,
    $artifacts,
    $keepForever,
    $collectionUrl,
    $teamproject,
    $releaseid,
    $buildid,
    $token
)

function Set-BuildRetension
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildID,
        $keepForever,
        $usedefaultcreds,
        $token
    )

    $boolKeepForever = [System.Convert]::ToBoolean($keepForever)

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Setting BuildID $buildID with retension set to $boolKeepForever"

    try {
        $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildID)?api-version=2.0"
        $data = @{keepForever = $boolKeepForever} | ConvertTo-Json
        $response = $webclient.UploadString($uri,"PATCH", $data)
    } catch
    {
        Write-Error "Cannot update the build, probably a rights issues see https://github.com/rfennell/AzurePipelines/wiki/BuildTasks-Task (foot of page) to see notes on granting rights"
    }
}

function Get-BuildsForRelease
{
    param
    (
        $tfsuri,
        $teamproject,
        $releaseID,
        $usedefaultcreds,
        $token
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Getting Builds for Release releaseID"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up
    $rmtfsUri = $tfsUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection"

    # at september 2018 this API is also available at vsrm.dev.azure.com
    $rmtfsUri = $rmtfsUri -replace "dev.azure.com", "vsrm.dev.azure.com"

    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseId)?api-version=3.0-preview"
    $response = $webclient.DownloadString($uri)

    $data = $response | ConvertFrom-Json

    $return = @()
    $data.artifacts.Where({$_.type -eq "Build"}).ForEach( {
        $return +=  @{ 'id' = $_.definitionReference.version.id;
                       'name' = $_.alias }
    })

    $return

}


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


# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

Write-Verbose "collectionUrl = [$collectionUrl]"
# we may have added quotes as we passed through PSCore
$teamproject = $teamproject.Trim("'")
Write-Verbose "teamproject = [$teamproject]"
Write-Verbose "releaseid = [$releaseid]"
Write-Verbose "buildid = [$buildid]"
Write-Verbose "usedefaultcreds =[$usedefaultcreds]"
Write-Verbose "artifacts = [$artifacts]"
Write-Verbose "mode = [$mode]"
Write-Verbose "keepForever = [$keepForever]"

if([string]::IsNullOrEmpty($releaseid))
{
    Write-Host ("Running task within a build, only 'Prime' mode supported i.e. update the retension on the current build")
    $mode = "Prime"
}

if ($mode -eq "AllArtifacts")
{
    Write-Verbose ("Updating all artifacts")
    $builds = Get-BuildsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds -token $token
    foreach($build in $builds)
    {
        Write-Verbose ("Updating artifact $build.name")
        Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -keepForever $keepForever -usedefaultcreds $usedefaultcreds -token $token
    }
} elseif ($mode -eq "Prime")
{
    Write-Verbose ("Updating only primary artifact")
    Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -keepForever $keepForever -usedefaultcreds $usedefaultcreds -token $token
} else
{
    Write-Verbose ("Updating only named artifacts")
    if ([string]::IsNullOrEmpty($artifacts) -eq $true) {
        Write-Error ("The artifacts list to update is empty")
    } else {
        $artifactsArray = $artifacts -split "," | foreach {$_.Trim()}
        if ($artifactsArray -gt 0) {
            $builds = Get-BuildsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds -token $token
            Write-Verbose "$($builds.Count) builds found for release"
            foreach($build in $builds)
            {
                if ($artifactsArray -contains $build.name) {
                    Write-Verbose ("Updating artifact $($build.name)")
                    Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -keepForever $keepForever -usedefaultcreds $usedefaultcreds -token $token
                } else {
                    Write-Verbose ("Skipping artifact $($build.name) as not in named list")
                }
            }
        } else {
            Write-Error ("The artifacts list cannot be split")
        }
    }
}