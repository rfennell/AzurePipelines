param(
    [string]$protocol = "http" ,
    [string]$rmserver ,
    [string]$port = "1000",  
    [string]$teamProject ,   
    [string]$targetStageName ,
    [string]$waitForCompletion ,
	[string]$buildtype = "VNEXT" ,
	[string]$username , # optional if not used default creds assumed
	[string]$password ,
	[string]$domain 
	
)
$VerbosePreference ='Continue' # equiv to -verbose

if ($buildtype -ne "VNEXT")
{
	# must be xaml
	$teamFoundationServerUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
	$buildDefinition = $env:BUILD_DEFINITIONNAME
	$buildNumber = $env:BUILD_BUILDNUMBER
} else {
	# must be vnext
	$teamFoundationServerUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
	$buildDefinition = $env:BUILD_DEFINITIONNAME
	$buildNumber = $env:BUILD_BUILDNUMBER
}

write-verbose "Executing with the following parameters:`n"
write-verbose "  Protocol: $protocol"
write-verbose "  RMserver Name: $rmserver"
write-verbose "  Port number: $port"
write-verbose "  Team Foundation Server URL: $teamFoundationServerUrl"
write-verbose "  Team Project: $teamProject"
write-verbose "  Build Definition: $buildDefinition"
write-verbose "  Build Number: $buildNumber"
write-verbose "  Target Stage Name: $targetStageName`n"
write-verbose "  Wait for RM completion: $waitForCompletion`n"


$wait = [System.Convert]::ToBoolean($waitForCompletion)
$exitCode = 0

trap
{
  $e = $error[0].Exception
  $e.Message
  $e.StackTrace
  if ($exitCode -eq 0) { $exitCode = 1 }
}

$scriptName = $MyInvocation.MyCommand.Name
$scriptPath = Split-Path -Parent (Get-Variable MyInvocation -Scope Script).Value.MyCommand.Path

Push-Location $scriptPath    

$server = [System.Uri]::EscapeDataString($teamFoundationServerUrl)
$project = [System.Uri]::EscapeDataString($teamProject)
$definition = [System.Uri]::EscapeDataString($buildDefinition)
$build = [System.Uri]::EscapeDataString($buildNumber)
$targetStage = [System.Uri]::EscapeDataString($targetStageName)

$orchestratorService = "$($protocol)://$($rmserver):$port/account/releaseManagementService/_apis/releaseManagement/OrchestratorService"

$status = @{
    "2" = "InProgress";
    "3" = "Released";
    "4" = "Stopped";
    "5" = "Rejected";
    "6" = "Abandoned";
}

$uri = "$orchestratorService/InitiateReleaseFromBuild?teamFoundationServerUrl=$server&teamProject=$project&buildDefinition=$definition&buildNumber=$build&targetStageName=$targetStage"
write-verbose "Executing the following API call:`n`n$uri"

$wc = New-Object System.Net.WebClient
# rmuser should be part rm users list and he should have permission to trigger the release.

  if ([string]::IsNullOrEmpty($username))
    {
		write-verbose "Using default credentials`n"
        $wc.UseDefaultCredentials = $true
    } else 
    {
		write-verbose "Using username [$username] parameters`n"	
    	$wc.Credentials = new-object System.Net.NetworkCredential($username, $password, $domain)
    }

try
{
    $releaseId = $wc.DownloadString($uri)
    $url = "$orchestratorService/ReleaseStatus?releaseId=$releaseId"
    $releaseStatus = $wc.DownloadString($url)

    if ($wait -eq $true)
    {
        Write-verbose "`nReleasing ..."

        while($status[$releaseStatus] -eq "InProgress")
        {
            Start-Sleep -s 5
            $releaseStatus = $wc.DownloadString($url)
            Write-verbose  "."
        }
        Write-verbose (" done.`n`nRelease completed with {0} status." -f $status[$releaseStatus])
    } else {
        Write-verbose "`nTriggering Release and exiting"
    }
}
catch [System.Exception]
{
    if ($exitCode -eq 0) { $exitCode = 1 }
    Write-error "`n$_`n" 
}

if ($exitCode -eq 0)
{
    if ($wait -eq $true)
    {
        if ($releaseStatus -eq 3)
        {
          "`nThe script completed successfully. Product deployed without error`n"
        } else {
            Write-verbose "`nThe script completed successfully. Product failed to deploy`n" 
            $exitCode = -1 # reset the code to show the error
        }
    } else {
        Write-verbose "`nThe script completed successfully. Product deploying`n"
    }
}
else
{
  $err = "Exiting with error: " + $exitCode + "`n"
  Write-error $err
}

Pop-Location
exit $exitCode