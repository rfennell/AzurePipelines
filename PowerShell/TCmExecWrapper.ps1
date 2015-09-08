function Get-BuildDetailsByNumber
{
    param
    (
        $tfsUri ,
        $buildNumber,
        $username, 
        $password
    )
    $uri = "$($tfsUri)/_apis/build/builds?api-version=2.0&buildnumber=$buildNumber"
    $wc = New-Object System.Net.WebClient
    if ($username -eq $null)
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
        $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
    }
	write-verbose "Getting ID of $buildNumber from $tfsUri "
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value[0]
}

function Set-BuildTag
{
    param
    (
        $tfsUri ,
        $buildID,
        $tag,
        $username, 
        $password
    )
    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    if ($username -eq $null)
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
        $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
    }
    write-verbose "Setting BuildID $buildID with Tag $tag via $tfsUri "
    $uri = "$($tfsUri)/_apis/build/builds/$($buildID)/tags/$($tag)?api-version=2.0"
    $data = @{value = $tag } | ConvertTo-Json
    $wc.UploadString($uri,"PUT", $data) 
}

function Set-BuildRetension
{
    param
    (
        $tfsUri ,
        $buildID,
        $keepForever,
        $username, 
        $password
    )
    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    if ($username -eq $null)
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
        $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
    }
    write-verbose "Setting BuildID $buildID with retention set to $keepForever via $tfsUri "
    $uri = "$($tfsUri)/_apis/build/builds/$($buildID)?api-version=2.0"
    $data = @{keepForever = $keepForever} | ConvertTo-Json
    $response = $wc.UploadString($uri,"PATCH", $data) 
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose
$ErrorActionPreference = 'Continue' # so the script completes if TCM sets an error level

write-verbose "ErrorActionPreference set to $ErrorActionPreference"

$folder = Split-Path -Parent $MyInvocation.MyCommand.Definition

& "$folder\TcmExec.ps1" -Collection $Collection -Teamproject $Teamproject -PlanId $PlanId  -SuiteId $SuiteId -ConfigId $ConfigId -BuildDirectory $PackageLocation -TestEnvironment $TestEnvironment -SettingsName $SettingsName # -BuildNumber $BuildNumber -BuildDefinition $BuildDefinition -LoginCreds "$TestUserUid,$TestUserPwd"
write-verbose "ErrorActionPreference set to $ErrorActionPreference"

write-verbose "TCM exited with code '$LASTEXITCODE'"
$newquality = "Test Passed"
$tag = "Deployed to Lab"
$keep = $true
if ($LASTEXITCODE -gt 0 )
{
	$newquality = "Test Failed"
	$tag = "Lab Deployed failed"
	$keep = $false
}
write-verbose "Setting build tag to '$tag'"


$url = "$Collection/$Teamproject"
$jsondata = Get-BuildDetailsByNumber -tfsUri $url -buildNumber $BuildNumber #-username $TestUserUid -password $TestUserPwd
$buildId = $jsondata.id
write-verbose "The build ID is $buildId"
 
write-verbose "The build tag set to '$tag' and retention set to '$key'"
Set-BuildTag -tfsUri $url  -buildID $buildId -tag $tag #-username $TestUserUid -password $TestUserPwd
Set-BuildRetension -tfsUri $url  -buildID $buildId  -keepForever $keep #-username $TestUserUid -password $TestUserPwd

# now fail the stage after we have sorted the logging
if ($LASTEXITCODE -gt 0 )
{
	Write-error "Test have failed"
}