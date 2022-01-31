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
)


$tfsUri = Get-VstsInput -Name "tfsUri"
$teamproject = Get-VstsInput -Name "teamproject"
$defname = Get-VstsInput -Name "defname"
$artifactname = Get-VstsInput -Name "artifactname"
$buildnumber = Get-VstsInput -Name "buildnumber"
$username = Get-VstsInput -Name "username"
$password = Get-VstsInput -Name "password"
$localdir = Get-VstsInput -Name "localdir"

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose


function Get-WebClient
{
 param
    (
        [string]$username,
        [string]$password
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"

    if ([System.String]::IsNullOrEmpty($password))
    {
        $wc.UseDefaultCredentials = $true
    } else
    {
       # This is the form for basic creds so either basic cred (in TFS/IIS) or alternate creds (in VSTS) are required"
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

function Get-BuildId
{

    param
    (
    $tfsUri,
    $teamproject,
    $defid,
    $buildnumber,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&buildnumber=$($buildnumber)"
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
    $artifactname,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/artifacts?api-version=2.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value | Where-Object {$_.name -eq $artifactname} | Select-Object -property @{Name="Path"; Expression = {$_.resource.data}}
}



# $localdir = $env:SYSTEM_ARTIFACTSDIRECTORY
# for local testing override this environment variable
# $localdir = "c:\tmp"

Write-Verbose "Getting details of build [$defname] from server [$tfsUri/$teamproject]"
$defId = Get-BuildDefinitionId -tfsUri $tfsUri -teamproject $teamproject -defname $defname -username $username -password $password
if (([System.String]::IsNullOrEmpty($buildnumber)) -or ($buildnumber -eq "<Lastest Build>"))
{
    write-verbose "Getting lastest completed build"
    $buildId = Get-LastSuccessfulBuildId -tfsUri $tfsUri -teamproject $teamproject -defid $defid -username $username -password $password
} else
{
    write-verbose "Getting build number [$buildnumber]"
    $buildId = Get-BuildId -tfsUri $tfsUri -teamproject $teamproject -defid $defid -buildnumber $buildnumber -username $username -password $password
}
$artifact = Get-BuildArtifactPath -tfsUri $tfsUri -teamproject $teamproject -buildid $buildId -artifactname $artifactname -username $username -password $password

if (($artifact -ne $null) -and ([System.String]::IsNullOrEmpty($artifact.path)))
{
    Write-Error "Build has no UNC drop"
} else
{
    if (Test-Path $artifact.path)
    {
        if (Test-Path $localdir)
        {
            Write-verbose "Copying [$($artifact.path)] to [$localdir\$defname]"
            Copy-Item $artifact.path $localdir\$defname -recurse -Force
        } else
        {
            Write-Error "Cannot access target path [$localdir]"
         }
    } else
    {
        Write-Error "Cannot access source path [$($artifact.path)]"
    }
}