[CmdletBinding()]
Param(
)
   
function Set-BuildRetension
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildID,
        $keepForever,
        $usedefaultcreds
    )

    $boolKeepForever = [System.Convert]::ToBoolean($keepForever)

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds
    
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
        $usedefaultcreds
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds
    
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
       $usedefaultcreds
    )

    $webclient = new-object System.Net.WebClient
	
    if ([System.Convert]::ToBoolean($usedefaultcreds) -eq $true)
    {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    } else {
        Write-Verbose "Using SystemVssConnection personal access token"
        $vstsEndpoint = Get-VstsEndpoint -Name SystemVssConnection -Require
        $webclient.Headers.Add("Authorization" ,"Bearer $($vstsEndpoint.auth.parameters.AccessToken)")
    }

    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $webclient.Headers["Content-Type"] = "application/json"
    $webclient

}


# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

$mode = Get-VstsInput -Name "mode"  
$usedefaultcreds = Get-VstsInput -Name "usedefaultcreds" 
$artifacts = Get-VstsInput -Name "artifacts"   
$keepForever = Get-VstsInput -Name "keepForever" 

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$buildid = $env:BUILD_BUILDID

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "buildid = [$env:BUILD_BUILDID]"
Write-Verbose "usedefaultcreds =[$usedefaultcreds]"
Write-Verbose "artifacts = [$artifacts]"
Write-Verbose "mode = [$mode]"
Write-Verbose "keepForever = [$keepForever]"

if ($mode -eq "AllArtifacts")
{
    Write-Verbose ("Updating all artifacts")
    $builds = Get-BuildsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds
    foreach($build in $builds)
    {
        Write-Verbose ("Updating artifact $build.name")
        Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -keepForever $keepForever -usedefaultcreds $usedefaultcreds
    }
} elseif ($mode -eq "Prime") 
{
    Write-Verbose ("Updating only primary artifact")
    Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -keepForever $keepForever -usedefaultcreds $usedefaultcreds
} else 
{
    Write-Verbose ("Updating only named artifacts")
    if ([string]::IsNullOrEmpty($artifacts) -eq $true) {
        Write-Error ("The artifacts list to update is empty")
    } else {
        $artifactsArray = $artifacts -split "," | foreach {$_.Trim()}
        if ($artifactsArray -gt 0) {
            $builds = Get-BuildsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds
            Write-Verbose "$($builds.Count) builds found for release"
            foreach($build in $builds)
            {
                if ($artifactsArray -contains $build.name) {
                    Write-Verbose ("Updating artifact $($build.name)")
                    Set-BuildRetension -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -keepForever $keepForever -usedefaultcreds $usedefaultcreds
                } else {
                    Write-Verbose ("Skipping artifact $($build.name) as not in named list")
                }
            }
        } else {
            Write-Error ("The artifacts list cannot be split") 
        }
    }
}