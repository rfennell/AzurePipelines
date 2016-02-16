##-----------------------------------------------------------------------
## <copyright file="GetAtifactsFromUncShare.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Get the contents of a drop share and places on the local agent
#
# This task aims to be a temporary measure to allow one TFS server to get a drop
# from a second TFS server. Initially it does assume the drop is on a UNC share
# 

#Enable -Verbose option
[CmdletBinding()]
param (

    $tfsUri,
    $teamproject ,
    $defname ,
    $username  ,
    $password 
    
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose


function Get-WebClient
{
 param
    (
        [string]$username, 
        [string]$password
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    
    if ([System.String]::IsNullOrEmpty($password))
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
       $pair = "${username}:${password}"
       $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
       $base64 = [System.Convert]::ToBase64String($bytes)
       $wc.Headers.Add("Authorization","Basic $base64");
    }
 
    $wc
}


function Get-BuildDefinitionId
{

    param
    (
    $tfsUri,
    $teamproject,
    $defname,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0&name=$($defname)"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value.id 

}

function Get-LastSuccessfulBuildId
{

    param
    (
    $tfsUri,
    $teamproject,
    $defid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&statusFilter=completed&`$top=1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value.id
}

function Get-BuildArtifactPath
{

    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/artifacts?api-version=2.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value.resource
}



$localdir = $env:SYSTEM_ARTIFACTSDIRECTORY


Write-Verbose "Getting details of build [$defname] from server [$tfsUri/$teamproject]"
$defId = Get-BuildDefinitionId -tfsUri $tfsUri -teamproject $teamproject -defname $defname -username $username -password $password
$buildId = Get-LastSuccessfulBuildId -tfsUri $tfsUri -teamproject $teamproject -defid $defid -userrname $username -password $password
$artifact = Get-BuildArtifactPath -tfsUri $tfsUri -teamproject $teamproject -buildid $buildId -userrname $username -password $password

if (($artifact -ne $null) -and ([System.String]::IsNullOrEmpty($artifact.data)))
{
    Write-Error "Build has no UNC drop"

} else 
{
    if (Test-Path $artifact.data)
    {
        Write-verbose "Copying [$($artifact.data)] to [$localdir\$defname]"
        Copy-Item $artifact.data $localdir\$defname -recurse
    } else
    {
        Write-Error "Cannot access path [$($artifact.data)]"
    }
}