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
    $emptySetText 
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

Import-Module -Name "$PSScriptRoot\GenerateReleaseNotes.psm1" 

# Get the build and release details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$releaseid = $env:RELEASE_RELEASEID
$releasedefid = $env:RELEASE_DEFINITIONID
$buildid = $env:BUILD_BUILDID
$defname = $env:BUILD_DEFINITIONNAME
$buildnumber = $env:BUILD_BUILDNUMBER

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "releasedefid = [$env:RELEASE_DEFINITIONID]"
Write-Verbose "stageName = [$env:RELEASE_ENVIRONMENTNAME]"
Write-Verbose "overrideStageName = [$overrideStageName]"
Write-Verbose "buildid = [$env:BUILD_BUILDID]"
Write-Verbose "defname = [$env:BUILD_DEFINITIONNAME]"
Write-Verbose "buildnumber = [$env:BUILD_BUILDNUMBER]"
Write-Verbose "outputVariableName = [$outputvariablename]"


if ( [string]::IsNullOrEmpty($releaseid))
{
    
   Write-Verbose "In Build mode"
   $builds = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds
    
} else
{
	Write-Verbose "In Release mode"
 
    $releases = @()
    if ($generateForCurrentRelease -eq $true)
    {
        Write-Verbose "Only processing current release"
        # we only need the current release
        $releases += Get-Release -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid -usedefaultcreds $usedefaultcreds
    } else 
    {
        # work out the name of the stage to compare the release against
        if ( [string]::IsNullOrEmpty($overrideStageName))
        {
            $stageName = $env:RELEASE_ENVIRONMENTNAME
        } else 
        {
            $stageName = $overrideStageName
        }

        Write-Verbose "Processing all releases back to the last successful release in stage [$stageName]"
           
        $allRelease = Get-ReleaseByDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -releasedefid $releasedefid -usedefaultcreds $usedefaultcreds
        #find the set of release since the last good release of a given stage
        foreach ($r in $allRelease)
        {
            if ($r.id -eq $releaseid )
            {
                # we always add the current release that trigger the task
                $releases += $r
            } else 
            {
                # add all the past releases where the this stahe ws not a success
                $stage = $r.environments | Where-Object { $_.name -eq $stageName -and $_.status -ne "succeeded" }
                if ($stage -ne $null)
                {
                    $releases += $r
                } else {
                    #we have found a successful relase in this stage so quit
                    break
                }
            }       
        }
    }
    
    Write-Verbose "Discovered [$($releases.Count)] releases for processing"

    # we put all the builds into a hastable associated with their release
    $buildsList = @{}
    foreach ($release in $releases)
    {
        Write-Verbose "Processing the release [$($release.id)]"
        foreach ($artifact in (Get-BuildReleaseArtifacts -tfsUri $collectionUrl -teamproject $teamproject -release $release -usedefaultcreds $usedefaultcreds))
        {
            if (($generateForOnlyPrimary -eq $true -and $artifact.isPrimary -eq $true) -or ($generateForOnlyPrimary -eq $false))
            {
                if ($artifact.type -eq 'Build')
                {
					if (($buildsList.ContainsKey($artifact.definitionReference.version.id)) -eq $false)
					{
						Write-Verbose "The artifact [$($artifact.alias)] is a VSTS build, will attempt to find associated commits/changesets and work items"
						$b = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $artifact.definitionReference.version.id -usedefaultcreds $usedefaultcreds
						$buildsList.Add($artifact.definitionReference.version.id , $b)
					} else
					{
						Write-Verbose "The artifact [$($artifact.alias)] is a VSTS build, but already in the build list is is being skipped"
					}
				} else 
                {
                    Write-Verbose "The artifact [$($artifact.alias)] is a [$($artifact.type)], will be skipped as has no associated commits/changesets and work items"
                }
            } else 
            {
            Write-Verbose "The artifact [$($artifact.alias)] is being skipped as it is not the primary artifact"
            }
        }
    }
	
	# also for backwards compibiluty we swap the hash table for a simple array in build create order (we assume buildID is incrementing)
	$builds = $($buildsList.GetEnumerator() | Sort-Object { $_.Value.build.id }).Value
}

$template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
$outputmarkdown = Invoke-Template -template $template -builds $builds -releases $releases -stagename $stageName

write-Verbose "Writing output file [$outputfile]."
Set-Content $outputfile $outputmarkdown

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



