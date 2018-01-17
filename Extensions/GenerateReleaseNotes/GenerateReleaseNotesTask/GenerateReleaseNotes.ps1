##-----------------------------------------------------------------------
## <copyright file="Create-ReleaseNotes.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Create as a Markdown Release notes file for a build froma template file
#
# Where the format of the template file is as follows
# Note the use of @@WILOOP@@ and @@CSLOOP@@ marker to denotes areas to be expended 
# based on the number of work items or change sets
# Other fields can be added to the report by accessing the $build, $wiDetail and $csdetail objects
#
# #Release notes for build $defname  `n
# **Build Number**  : $($build.buildnumber)   `n
# **Build completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.finishTime)   `n   
# **Source Branch** $($build.sourceBranch)   `n
# 
# ###Associated work items   `n
# @@WILOOP@@
# * **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')] $($widetail.fields.'System.Title')
# @@WILOOP@@
# `n
# ###Associated change sets/commits `n
# @@CSLOOP@@
# * **ID $($csdetail.id)** $($csdetail.message)
# @@CSLOOP@@


#Enable -Verbose option
[CmdletBinding()]
param (
 
    [parameter(Mandatory=$false,HelpMessage="The markdown output file")]
    $outputfile ,

    [parameter(Mandatory=$false,HelpMessage="The markdown output variable name")]
    $outputvariablename ,

    [parameter(Mandatory=$false,HelpMessage="The markdown template file")]
    $templatefile ,
	
    [parameter(Mandatory=$false,HelpMessage="The inline markdown template")]
    $inlinetemplate, 
	
	[parameter(Mandatory=$false,HelpMessage="Location of markdown template")]
    $templateLocation,

	[parameter(Mandatory=$false,HelpMessage="If true use default credentials, else get them from VSTS")]
    $usedefaultcreds, 

	[parameter(Mandatory=$false,HelpMessage="If running in a release to only generate for primary artifact")]
    $generateForOnlyPrimary,

	[parameter(Mandatory=$false,HelpMessage="Only consider the current release")]
    $generateForCurrentRelease,
    
	[parameter(Mandatory=$false,HelpMessage="Overide the name of the release stage to compare against")]
     $overrideStageName,

	[parameter(Mandatory=$false,HelpMessage="Overide the text to put in generated files if no data returned")]
    $emptySetText,
    
    [parameter(Mandatory=$false,HelpMessage="Overide the default of 50 changesets/commits items returned")]
    $maxChanges, 

    [parameter(Mandatory=$false,HelpMessage="Overide the default of 50 work items returned")]
    $maxWi,

    [parameter(Mandatory=$false,HelpMessage="A comma-separated list of Work Item types that should be included in the output.")]
    $wiFilter,

    [parameter(Mandatory=$false,HelpMessage="A comma-separated list of Work Item states that should be included in the output.")]
    $wiStateFilter,

    [parameter(Mandatory=$false,HelpMessage="A boolean flag whether to added parent work items of those associated with a build.")]
    $showParents,

    [parameter(Mandatory=$false,HelpMessage="A boolean flag whether to over-write output file or append to it.")]
    $appendToFile

)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

Import-Module -Name "$PSScriptRoot\GenerateReleaseNotes.psm1" -Force 

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$releasedefid = $env:RELEASE_DEFINITIONID
$buildid = $env:BUILD_BUILDID
$builddefname = $env:BUILD_DEFINITIONNAME
$releasedefname = $env:RELEASE_DEFINITIONNAME
$buildnumber = $env:BUILD_BUILDNUMBER
$currentStageName = $env:RELEASE_ENVIRONMENTNAME

if ( ([string]::IsNullOrEmpty($releaseid) -eq $false) -and [string]::IsNullOrEmpty($releasedefid) )
{
    Write-Verbose "Looking up ReleaseDefId for TFS2015.2"
    # we are in release mode, checking we have a releasedefif, if not look it up - needed for TFS2015.2
    $releasedefinition = Get-ReleaseDefinitionByName -tfsUri $collectionUrl -teamproject $teamproject -releasename $releasedefname -usedefaultcreds $usedefaultcreds
    $releasedefid = $releasedefinition.id
}

Write-Verbose "collectionUrl = [$collectionUrl]"
Write-Verbose "teamproject = [$teamproject]"
Write-Verbose "releaseid = [$releaseid]"
Write-Verbose "releasedefid = [$releasedefid]"
Write-Verbose "stageName = [$currentStageName]"
Write-Verbose "overrideStageName = [$overrideStageName]"
Write-Verbose "buildid = [$buildid]"
Write-Verbose "builddefname = [$builddefname]"
Write-Verbose "releasedefname = [$releasedefname]"
Write-Verbose "buildnumber = [$buildnumber]"
Write-Verbose "outputVariableName = [$outputvariablename]"
Write-Verbose "generateForOnlyPrimary = [$generateForOnlyPrimary]"
Write-Verbose "generateForCurrentRelease = [$generateForCurrentRelease]"
Write-Verbose "maxWi = [$maxWi]"
Write-Verbose "maxChanges = [$maxChanges]"
Write-Verbose "showParents  =[$showParents]"
Write-Verbose "wiFilter = [$wiFilter]"
Write-Verbose "wiStateFilter = [$wiStateFilter]"
Write-Verbose "appendToFile = [$appendToFile]"

if ( [string]::IsNullOrEmpty($releaseid))
{
    
   Write-Verbose "In Build mode"
   $builds = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -maxWi $maxWi -maxChanges $maxChanges -wiFilter $wiFilter -wiStateFilter $wiStateFilter -showParents $showParents
    
} else
{
	Write-Verbose "In Release mode"
 
    $releases = @()
    $allReleases = @()
    if ($generateForCurrentRelease -eq $true)
    {
        Write-Verbose "Only processing current release"
        # we only need the current release
        $releases += Get-Release -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds
        $allReleases += $releases # add this for backwards support
        $stageName = $currentStageName
    } else 
    {
        # work out the name of the stage to compare the release against
        if ( [string]::IsNullOrEmpty($overrideStageName))
        {
            $stageName = $currentStageName
        } else 
        {
            $stageName = $overrideStageName
        }

        Write-Verbose "Processing all releases back to the last successful release in stage [$stageName]"
           
        $allReleases = Get-ReleaseByDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -releasedefid $releasedefid -usedefaultcreds $usedefaultcreds

        # find the set of release since the last good release of a given stage
        # we filter for any release newer than the current release 
        # we assume the releases are ordered by date
        foreach ($r in $allReleases | Where-Object { $_.id -le $releaseid })
        {
            if ($r.id -eq $releaseid )
            {
                # we always add the current release that trigger the task
                Write-Verbose "   Adding release [$r.id] to list"
                $releases += $r
            } else 
            {
                # add all the past releases where the this stage was not a success
                $stage = $r.environments | Where-Object { $_.name -eq $stageName -and $_.status -ne "succeeded" }
                if ($stage -ne $null)
                {
                    Write-Verbose "   Adding release [$r.id] to list"
                    $releases += $r
                } else {
                    #we have found a successful relase in this stage so quit
                    break
                }
            }       
        }
    }
    
    Write-Verbose "Discovered [$($releases.Count)] releases for processing after checking a total of [$($allReleases.Count)] releases"

    # we put all the builddefs into an array
    $buildsDefinitionList = @()
    
    # get our boundary releases, we have to force it to be an array in case there is a single entry
    $currentRelease = @($releases)[0]
    $lastSuccessfulRelease = @($releases)[-1]
  
    # find the list of artifacts
    foreach ($artifact in  $currentRelease.artifacts)
    {
        if (($generateForOnlyPrimary -eq $true -and $artifact.isPrimary -eq $true) -or ($generateForOnlyPrimary -eq $false))
        {
            if ($artifact.type -eq 'Build')
            {
                Write-Verbose "The artifact [$($artifact.alias)] is a VSTS build, will attempt to find associated commits/changesets and work items"
                $buildsDefinitionList +=($artifact.definitionReference.definition.id)
            } else 
            {
                Write-Verbose "The artifact [$($artifact.alias)] is a [$($artifact.type)], will be skipped as has no associated commits/changesets and work items"
            }
        }
    }

    # we put all the builds into a hashtable associated with their release
    $buildsList = @{}

    Write-Verbose "Found $($buildsDefinitionList.Count) build artifacts to check for builds that fall in range"

    foreach ($defId in $buildsDefinitionList)
    {
        Write-Verbose "Checking build artifacts for the Build Defintion ID $($defId)"
        $lastBuild = $currentRelease.artifacts | Where-Object { $_.definitionReference.definition.id -eq $defId} 
        $firstBuild = $lastSuccessfulRelease.artifacts | Where-Object { $_.definitionReference.definition.id -eq $defId} 
        foreach ($build in Get-BuildsByDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -buildDefid $defId -usedefaultcreds $usedefaultcreds)
        {
            # if build in build number range and completed
            if ($build.id -le $lastBuild.definitionReference.version.id -and ($build.id -gt $firstBuild.definitionReference.version.id -or $build.id -eq $lastBuild.definitionReference.version.id) -and $build.status -eq "completed")
            {
				$b = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -usedefaultcreds $usedefaultcreds -maxWi $maxWi -maxChanges $maxChanges -wiFilter $wiFilter -wiStateFilter $wiStateFilter -showParents $showParents
				$buildsList.Add($build.id , $b)
            }
        }
    }
	
	# also for backwards compibiluty we swap the hash table for a simple array in build create order (we assume buildID is incrementing)
	$builds = $($buildsList.GetEnumerator() | Sort-Object { $_.Value.build.id }).Value
}

$template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
$outputmarkdown = Invoke-Template -template $template -builds $builds -releases $releases -stagename $stageName -defname $builddefname -releasedefname $releasedefname

if ($appendToFile -eq $false)
{
    write-Verbose "Writing to output file [$outputfile]."
    Set-Content $outputfile $outputmarkdown 
} else 
{
    write-Verbose "Appending to output file [$outputfile]."
    Add-Content $outputfile $outputmarkdown 
}

if ([string]::IsNullOrEmpty($outputvariablename))
{
    write-Verbose "Skipping setting output variable name as parameter was not set."
} 
else 
{    
    # reload the file, this is quick fix for issues we see that only the first line 
    # is returned as in the output varibable if we just try to pipe the local variable
    $file = Get-Content $outputfile
    Write-Verbose "Setting variable: [$outputvariablename] = $file" -Verbose
    $joined = $file -join '`n'
    Write-Host ("##vso[task.setvariable variable=$outputvariablename;]$joined")
}



