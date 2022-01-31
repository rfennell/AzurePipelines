[CmdletBinding()]
param
(
    # Get the build and release details
    $collectionUrl,
    $teamproject,
    $releaseid,
    $builddefid,
    $buildid,
    $buildmode,
    $variable,
    $mode,
    $value,
    $usedefaultcreds,
    $artifacts,
    $token
)

function Set-BuildDefinationVariable
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID,
        $data,
        $usedefaultcreds,
        $apiVersion,
        $token

    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Updating Build Definition $builddefID for $($tfsUri)/$($teamproject)"

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=$apiVersion"
    $jsondata = $data | ConvertTo-Json -Compress -Depth 10 #else we don't get lower level items

    $response = $webclient.UploadString($uri,"PUT", $jsondata)
    $response

}

function Set-BuildVariableGroupVariable
{
    param
    (
        $tfsuri,
        $teamproject,
        $data,
        $usedefaultcreds,
        $token

    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Updating VariableGroup $variablegroupid for $($tfsUri)/$($teamproject)"


    $uri = "$($tfsUri)/$($teamproject)/_apis/distributedtask/variablegroups/$($data.id)?api-version=4.1-preview.1"
    $jsondata = $data | ConvertTo-Json -Compress -Depth 10 #else we don't get lower level items

    $response = $webclient.UploadString($uri,"PUT", $jsondata)
    $response

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


function Get-BuildDefination
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefID,
        $usedefaultcreds,
        $apiVersion,
        $token
    )

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token

    write-verbose "Getting Build Definition $builddefID "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($buildDefID)?api-version=$apiVersion"
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
        $usedefaultcreds,
        $apiVersion,
        $token
      )
    # get the old definition
    $def = Get-BuildDefination -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid -usedefaultcreds $usedefaultcreds -token $token

    $foundGroup = $null
    $item = $null
    if ($variable -in $def.variables.PSobject.Properties.Name)
    {
        Write-Verbose "Current value of the pipeline variable [$variable] is [$($def.variables.$variable.value)]"
        $item =$def.variables.$variable
    } else {
        Write-verbose "Variable is not found as a pipeline variable"
        # check if there is a variable group
	    if ($def.variableGroups) {
			foreach ($group in $def.variableGroups)
			{
				Write-verbose "Checking for variable in '$($group.name)'"
				if ($variable -in $group.variables.PSobject.Properties.Name)
				{
					write-verbose "group details $group"
					Write-Verbose "Current value of the variable [$variable] is [$($group.variables.$variable.value)] in [$($group.name)] with ID [$($group.id)]"
					$item =$group.variables.$variable
					$foundGroup = $group
					break
				}
			}
		} else {
			Write-verbose "No Variable present to check"
       }
    }

    if ($item -ne $null)
    {
        if ($mode -eq "Manual")
        {
            Write-Verbose "Manually updating variable"
            $newValue = $value
        } else {
            Write-Verbose "Autoincrementing variable"
            try {
                $newValue = "$([convert]::ToInt32($item.value) +1)"
            } catch {
                Write-Error "Cannot increment variable [$variable] either the variable could not be found or the value is not numeric"
                return
            }
        }

       # make the change
       if ($foundGroup -eq $null) {
            Write-Verbose "Setting pipeline variable [$variable] to value [$newValue]"
            $item.value = $newValue
            try {
                # write it back
                $response = Set-BuildDefinationVariable -tfsuri $tfsuri -teamproject $teamproject -builddefid $builddefid -data $def -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
            } catch {
                Write-Error "Cannot update the build, probably a rights issues see https://github.com/rfennell/AzurePipelines/wiki/BuildTasks-Task (foot of page) to see notes on granting rights to the build user to edit build defintions"
            }
        } else {
            Write-Verbose "Setting [$($group.name)] variable [$variable] to value [$newValue]"
            $item.value = $newValue
            try {
                # write it back
                $response = Set-BuildVariableGroupVariable -tfsuri $tfsuri -teamproject $teamproject -data $group -usedefaultcreds $usedefaultcreds -token $token
            } catch {
                Write-Error "Cannot update the variable group, probably a rights issues see https://github.com/rfennell/AzurePipelines/wiki/BuildTasks-Task (foot of page) to see notes on making the build user an adminsitrator for the variable group"
            }
        }
    } else {
         Write-Error "Cannot set variable [$variable] as variable could not be found in the a pipeline or associated variablegroups"
    }
}

function Get-BuildsDefsForRelease
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
        Write-Verbose "Getting DefintionID $($_.definitionReference.definition.id) for build instance $($_.definitionReference.version.id)"
        $return +=  @{ 'id' =  $_.definitionReference.definition.id;
                       'name' = $_.alias }
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
    $usedefaultcreds,
    $apiVersion,
    $token
    )

    write-verbose "Getting BuildDef for Build"

    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds -token $token
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)?api-version=$apiVersion"
    $jsondata = $webclient.DownloadString($uri) | ConvertFrom-Json
    $jsondata
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

Write-Verbose "collectionUrl = [$collectionUrl]"
# we may have added quotes as we passed through PSCore
$teamproject = $teamproject.Trim("'")
Write-Verbose "teamproject = [$teamproject]"
Write-Verbose "releaseid = [$releaseid]"
Write-Verbose "builddefid = [$builddefid]"
Write-Verbose "buildid = [$buildid]"
Write-Verbose "usedefaultcreds = $usedefaultcreds"
Write-Verbose "artifacts = [$artifacts]"
Write-Verbose "buildmode = [$buildmode]"
Write-Verbose "mode = [$mode]"

Write-Verbose "Running inside a build so updating current build $buildid"
# Checking the version we have available, we need 4.0 for variable group, but 2.0 for TFS 2017
$apiVersion = "4.0"
write-verbose "Checking API version available"
try {
	$build = Get-Build -tfsuri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
} catch {
	$apiVersion = "2.0"
	$build = Get-Build -tfsuri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
}
write-verbose "API Version is $apiversion"

if ( [string]::IsNullOrEmpty($releaseid))
{
    Write-Verbose "Running inside a build so updating current build $buildid"

    write-Verbose "Using API-Verison $apiVersion"

    $builddefid = $build.definition.id
    Write-Verbose "Build has definition id of $builddefid"

    Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $builddefid -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
} else {
    Write-Verbose "Running inside a release so updating asking which build(s) to update"
    if ($buildmode -eq "AllArtifacts")
    {
        Write-Verbose ("Updating all artifacts")
        $builddefs = Get-BuildsDefsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds --token $token
        foreach($build in $builddefs)
        {
            Write-Verbose ("Updating artifact $build.name")
            Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $build.id -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
        }
    } elseif ($buildmode -eq "Prime")
    {
        Write-Verbose ("Updating only primary artifact")
        Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $builddefid -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
    } else
    {
        Write-Verbose ("Updating only named artifacts")
        if ([string]::IsNullOrEmpty($artifacts) -eq $true) {
            Write-Error ("The artifacts list to update is empty")
        } else {
            $artifactsArray = $artifacts -split "," | foreach {$_.Trim()}
            if ($artifactsArray -gt 0) {
                $builddefs = Get-BuildsDefsForRelease -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds -token $token
                Write-Verbose "$($builddefs.Count) builds found for release"
                foreach($build in $builddefs)
                {
                    if ($artifactsArray -contains $build.name) {
                        Write-Verbose ("Updating artifact $($build.name)")
                        Update-Build -tfsuri $collectionUrl -teamproject $teamproject -builddefid $build.id -mode $mode -value $value -variable $variable -usedefaultcreds $usedefaultcreds -apiVersion $apiVersion -token $token
                    } else {
                        Write-Verbose ("Skipping artifact $($build.name) as not in named list")
                    }
                }
            } else {
                Write-Error ("The artifacts list cannot be split")
            }
        }
    }
}

