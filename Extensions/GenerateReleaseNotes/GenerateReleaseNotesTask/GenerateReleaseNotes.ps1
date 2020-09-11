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
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

Import-Module -Name "$PSScriptRoot\GenerateReleaseNotes.psm1" -Force

Use-SystemWebProxy

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

$outputfile = Get-VstsInput -Name "outputfile"
$outputvariablename = Get-VstsInput -Name "outputvariablename"
$templatefile = Get-VstsInput -Name "templatefile"
$inlinetemplate = Get-VstsInput -Name "inlinetemplate"
$templateLocation = Get-VstsInput -Name "templateLocation"
$usedefaultcreds = Get-VstsInput -Name "usedefaultcreds"
$generateForOnlyPrimary = Get-VstsInput -Name "generateForOnlyPrimary"
$generateForOnlyTriggerArtifact = Get-VstsInput -Name "generateForOnlyTriggerArtifact"
$generateForCurrentRelease = Get-VstsInput -Name "generateForCurrentRelease"
$overrideStageName = Get-VstsInput -Name "overrideStageName"
$emptySetText = Get-VstsInput -Name "emptySetText"
$maxChanges= Get-VstsInput -Name "maxChanges"
$maxWi = Get-VstsInput -Name "maxWi"
$wiFilter = Get-VstsInput -Name "wiFilter"
$wiStateFilter= Get-VstsInput -Name "wiStateFilter"
$showParents = Get-VstsInput -Name "showParents"
$appendToFile = Get-VstsInput -Name "appendToFile"
$unifiedList = Get-VstsInput -Name "unifiedList"
$buildTags = Get-VstsInput -Name "buildTags"

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
Write-Verbose "generateForOnlyTriggerArtifact = [$generateForOnlyTriggerArtifact]"
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
                Write-Verbose "   Adding release [$r.id] to list as it is the current release"
                $releases += $r
            } else
            {
                # add all the past releases where the this stage was not a success
                $stage = $r.environments | Where-Object { $_.name -eq $stageName }
                if ($stage -ne $null)
                {
                    Write-Verbose "   Adding release [$r.id] to list"
                    $releases += $r
                    if ($stage.status -eq "succeeded")
                    {
                        # we have found a successful release in this stage so quit
                        Write-Verbose "   Finished adding releases as [$r.id] was a successful release"
                        break
                    }
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
    Write-Verbose "Found a potential list of $($currentRelease.artifacts.count) artifact"
    Write-Verbose "Filtering on primary artifact only [$($generateForOnlyPrimary)]"
    Write-Verbose "Filtering on trigger artifact only [$($generateForOnlyTriggerArtifact)]"

    foreach ($artifact in  $currentRelease.artifacts)
    {
        Write-Verbose "If looking for trigger artifact the comparision will be '$($currentRelease.description)' to 'Triggered by $($artifact.definitionReference.definition.name) $($artifact.definitionReference.version.id).'"
        
        #  the check for trigger build is nasty but the only means I can find
        if ((($generateForOnlyPrimary -eq $true) -and ($artifact.isPrimary -eq $true)) -or `
            (($generateForOnlyTriggerArtifact -eq $true) -and ($currentRelease.description -eq "Triggered by $($artifact.definitionReference.definition.name) $($artifact.definitionReference.version.id).")) -or `
            (($generateForOnlyPrimary -eq $false) -and ($generateForOnlyTriggerArtifact -eq $false) ))
        {
            if ($artifact.type -eq 'Build')
            {
                Write-Verbose "The artifact [$($artifact.alias)] is a VSTS build, will attempt to find associated commits/changesets and work items"
                $buildsDefinitionList +=($artifact.definitionReference.definition.id)
            } else
            {
                Write-Verbose "The artifact [$($artifact.alias)] is a [$($artifact.type)], will be skipped as has no associated commits/changesets and work items"
            }
        } else {
            Write-Verbose "The artifact [$($artifact.alias)] is being skipped as it is either not the primary artifact or triggering artifact"
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
        foreach ($build in Get-BuildsByDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -buildDefid $defId -usedefaultcreds $usedefaultcreds -buildTags $buildTags)
        {
            # Extra checks for for #561
            Write-Verbose "Comparing range values"
            Write-Verbose "Build ID $($build.id)"
            Write-Verbose "Build Status $($build.status)"

            $lastID = $lastBuild.definitionReference.version.id
            $firstID = $firstBuild.definitionReference.version.id

            if ($lastID -is [array]) {
                Write-Verbose "Converting array for lastID $lastID"
                $lastID = ($lastID | measure -Maximum).Maximum
            }
            if ($firstID -is [array]) {
                Write-Verbose "Converting array for firstID $firstID"
                $firstID = ($firstID | measure -Minimum).Minimum
            }

            Write-Verbose "Lastbuild ID $lastID"
            Write-Verbose "Firstbuild ID $firstID"
        
            # if build in build number range and completed
            if ($build.id -le $lastID -and ($build.id -gt $firstID -or $build.id -eq $lastID) -and $build.status -eq "completed")
            {
                if ($buildsList.ContainsKey($build.id) -eq $false)
                {
                    write-Verbose "Getting details of build $($build.id)"
				    $b = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -usedefaultcreds $usedefaultcreds -maxWi $maxWi -maxChanges $maxChanges -wiFilter $wiFilter -wiStateFilter $wiStateFilter -showParents $showParents
                    $buildsList.Add($build.id , $b)
                } else {
                    write-Verbose "Skipping getting details of build $($build.id) as already processed"
                }
            }
        }
    }

	# also for backwards compibiluty we swap the hash table for a simple array in build create order (we assume buildID is incrementing)
    $builds = $($buildsList.GetEnumerator() | Sort-Object { $_.Value.build.id }).Value
}

if ( [string]::IsNullOrEmpty($releaseid) -eq $false)
{
    write-Verbose "In release mode so checking if wi/commits should be returned as unified lists"
    if ($unifiedList -eq $true)
    {
        write-Verbose "Processing a unified set of WI/Commits, removing duplicates from $($builds.count) builds"

        # reduce the builds
        $unifiedWorkitems = @{};
        $unifiedChangesets = @{};

        foreach ($build in $builds)
        {
            Write-Verbose "Processing Build $($build.build.id)"

            Write-Verbose "  Checking workitems"
            foreach($wi in $build.workitems)
            {
                if ($unifiedWorkItems.ContainsKey($wi.id) -eq $false)
                {
                    Write-Verbose "     Adding WI $($wi.id) to unified set"
                    $unifiedWorkItems.Add($wi.id, $wi)
                } else
                {
                    Write-Verbose "     Skipping WI $($wi.id) as already in unified set"
                }
            }

            Write-Verbose "  Checking Changesets/Commits"

            foreach($changeset in $build.changesets)
            {
                # the ID field differs from GIT to TFVC
                $id = $changeset.commitId # local git
                if ($id -eq $null)
                {
                    $id = $changeset.id  #github
                }
                if ($id -eq $null)
                {
                    $id = $changeset.changesetid #tgvc
                }
                if ($id -eq $null)
                {
                    write-error "Cannot find the commit/changeset ID"
                } else
                {
                    # we use hash as the ID changes between GIT and TFVC
                    if ($unifiedChangesets.ContainsKey($id) -eq $false)
                    {
                        Write-Verbose "     Adding Changeset/Commit with hash $id to unified set"
                        $unifiedChangesets.Add($id, $changeset)
                    } else
                    {
                        Write-Verbose "     Skipping Changeset/Commit $id as already in unified set"
                    }
                }
            }
        }

        write-Verbose "Returning a sorted unified set of $($unifiedWorkItems.count) Workitems and $($unifiedChangesets.count) Changesets/Commits"

        $builds = @{ 'build' = 0; # a dummy build as not interested in build detail
                     'workitems' = $($unifiedWorkitems.GetEnumerator() | Sort-Object { $_.Key }).Value;
                     'changesets' = $($unifiedChangesets.GetEnumerator() | Sort-Object { $_.Key }).Value;
                    }
    } else
    {
        write-Verbose "Return a nested set of builds each with their own WI/Commits, hence report can have duplicated workitems and commits"
    }
}

$template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
$outputmarkdown = Invoke-Template -template $template -builds $builds -releases $releases -stagename $stageName -defname $builddefname -releasedefname $releasedefname -emptySetText $emptySetText

if ($appendToFile -eq $false)
{
    write-Verbose "Writing to output file [$outputfile]."
    Set-Content -Path $outputfile -Value $outputmarkdown -Encoding UTF8
} else
{
    write-Verbose "Appending to output file [$outputfile]."
    Add-Content -Path $outputfile -Value $outputmarkdown -Encoding UTF8
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



