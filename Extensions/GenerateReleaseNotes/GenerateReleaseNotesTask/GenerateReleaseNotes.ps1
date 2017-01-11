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

function Get-BuildWorkItems
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $usedefaultcreds
    )

    Write-Verbose "Getting associated work items for build [$($buildid)]"

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds| ConvertFrom-Json
    $wiList = @();
  	foreach ($wi in $jsondata.value)
    {
       $wiList += Get-Detail -uri $wi.url
    } 
    $wiList
}

function Get-BuildChangeSets
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $usedefaultcreds
    )

    Write-Verbose "Getting associated changesets/commits for build [$($buildid)]"
   
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
  	$csList = @();
  	foreach ($cs in $jsondata.value)
    {
       # we can get more detail if the changeset is on VSTS or TFS
       try {
          $csList += Get-Detail -uri $cs.location
       } catch
       {
          Write-warning "Unable to get details of changeset/commit as it is not stored in TFS/VSTS"
          Write-warning "For [$($cs.id)] location [$($cs.location)]"
          Write-warning "Just using the details we have from the build"
          $csList += $cs
       }
    } 
    $csList
}

function Get-Detail
{
    param
    (
    $uri,
    $usedefaultcreds
    )

  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
  	$jsondata
}

function Get-Build
{

    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $usedefaultcreds
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
  	$jsondata 
}

function Get-Release
{

    param
    (
    $tfsUri,
    $teamproject,
    $releaseid,
    $usedefaultcreds
    )

    Write-Verbose "Getting details of release [$releaseid] from server [$tfsUri/$teamproject]"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up   
	$rmtfsUri = $tfsUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseid)?api-version=3.0-preview"

  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
  	$jsondata
}

function Get-BuildReleaseArtifacts
{

    param
    (
    $tfsUri,
    $teamproject,
    $release,
    $usedefaultcreds
    )

	# get the build artifacts
    $artifacts = $release.artifacts
	$artifacts
}

function Indent-Space
{
    param(
       $size =3,
       $indent =1
       )
    
    $upperBound = $size * $indent
    for ($i =1 ; $i -le $upperBound  ; $i++)
    {
        $padding += " "
    } 
    $padding
}

function Invoke-GetCommand
{
    param
    (
     $uri,
     $usedefaultcreds
    )

    $webclient = new-object System.Net.WebClient
    $webclient.Encoding = [System.Text.Encoding]::UTF8
	
    if ([System.Convert]::ToBoolean($usedefaultcreds) -eq $true)
    {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    } else {
        Write-Verbose "Using SystemVssConnection personal access token"
        $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
        $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
        $webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
    }
    
	#write-verbose "REST Call [$uri]"
    $webclient.DownloadString($uri)
}



function Render() {
    [CmdletBinding()]
    param ( [parameter(ValueFromPipeline = $true)] [string] $str)

    #buggy in V4 seems ok in older and newer
    #$ExecutionContext.InvokeCommand.ExpandString($str)

    "@`"`n$str`n`"@" | iex
}

function Get-Template 
{
	param (
		$templateLocation,
		$templatefile,
		$inlinetemplate
	)
	
	Write-Verbose "Using template mode [$templateLocation]"

	if ($templateLocation -eq 'File')
	{
    	write-Verbose "Loading template file [$templatefile]"
		$template = Get-Content $templatefile
	} else 
	{
    	write-Verbose "Using in-line template"
		# it appears as single line we need to split it out
		$template = $inlinetemplate -split "`n"
	}
	
	$template
}

function Get-Mode
{
    Param(
       $line
    )

     $mode = [Mode]::BODY
     if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::WI}
     if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::CS}
	 if ($line.Trim() -eq "@@BUILDLOOP@@") {$mode = [Mode]::BUILD}
     $mode
}

function Create-StackItem
{

    param
    (
        $items,
        $modeStack,
        $mode,
        $index
    )
    # Create a queue of the items
    $queue = new-object  System.Collections.Queue
    # add each item to the queue  
    foreach ($item in @($items))
    {
       $queue.Enqueue($item)
    }
    Write-Verbose "$(Indent-Space -indent ($modeStack.Count +1))$($queue.Count) items"
    # place it on the stack with the blocks mode and start line index
    $modeStack.Push(@{'Mode'= $mode;
                      'BlockQueue'=$queue;
                      'Index' = $index})
}

function Process-Template 
{
	Param(
	  $template,
      $builds
	)
	
	if ($template.count -gt 0)
	{
		write-Verbose "Processing template"
		write-verbose "There are [$($builds.count)] builds to process"

        # create our work stack and initialise
		$modeStack = new-object  System.Collections.Stack 
		$modeStack.Push([Mode]::BODY)

        # this line is to provide support the the legacy build only template
        # if using a release template it will be reset when processing tags
        $builditem = $builds
		$build = $builditem.build # using two variables for legacy support
        
		#process each line
		For ($index =0; $index -lt $template.Count; $index++)
		{
            $line = $template[$index]
            # get the line change mode if any
            $mode = Get-Mode -line $line

            #debug logging
            #Write-Verbose "$Index[$($mode)]: $line"

            if ($mode -ne [Mode]::BODY)
            {
                # is there a mode block change
                if ($modeStack.Peek().Mode -eq $mode)
                {
                    # this means we have reached the end of a block
                    # need to work out if there are more items to process 
                    # or the end of the block
                    $queue = $modeStack.Peek().BlockQueue;
                    if ($queue.Count -gt 0)
                    {
                        # get the next item and initialise
                        # the variables exposed to the template
                        $item = $queue.Dequeue()
                        # reset the index to process the block
                        $index = $modeStack.Peek().Index
                        switch ($mode)
			            {
			            "WI" {
                            Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting next workitem $($item.id)"
		                    $widetail = $item  
                         }
                         "CS" {
                            Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting next changeset/commit $($item.id)"
		                    $csdetail = $item 
                         }
                         "BUILD" {
                            Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting next build $($item.build.id)"
		                    $builditem = $item
                            $build = $builditem.build # using two variables for legacy support
                         }
                         } #end switch
                    }
                    else
                    {
                        # end of block and no more items, so exit the block
                        $mode = $modeStack.Pop().Mode
                        Write-Verbose "$(Indent-Space -indent $modeStack.Count)Ending block $mode"
                    }
                } else {
                    # this a new block to add the stack
                    # need to get the items to process and place them in a queue
                    Write-Verbose "$(Indent-Space -indent ($modeStack.Count))Starting block $($mode)"
                ###    $queue = new-object  System.Collections.Queue  
                    #set the index to jump back to
                    $lastBlockStartIndex = $index       
                    switch ($mode)
			        {
			            "WI" {
                            # store the block and load the first item
                            Create-StackItem -items @($builditem.workItems) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                                $widetail = $modeStack.Peek().BlockQueue.Dequeue()
                                Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting first workitem $($widetail.id)"
                            } else {
                                $widetail = $null
                            }
                         }
                         "CS" {
                            # store the block and load the first item
                            Create-StackItem -items @($builditem.changesets) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                               $csdetail = $modeStack.Peek().BlockQueue.Dequeue()   
                               Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting first changeset/commit $($csdetail.id)"
		                    
                            } else {
                                $csdetail = $null
                            }
                                                      
                         }
                        "BUILD" {
                            Create-StackItem -items @($builds) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                               $builditem = $modeStack.Peek().BlockQueue.Dequeue() 
                               $build = $builditem.build
                               Write-Verbose "$(Indent-Space -indent $modeStack.Count)Getting first build $($build.id)"
		                   
                            }  else {
                                $builditem = $null
                                $build = $null
                            }
                         }
                    }
                }
            } else
            {
            if ((($modeStack.Peek().mode -eq [Mode]::WI) -and ($widetail -eq $null)) -or 
                (($modeStack.Peek().mode -eq [Mode]::CS) -and ($csdetail -eq $null)))
            {
                # there is no data to expand
                $out += $emptySetText
            } else {
               	# nothing to expand just process the line
				$out += $line | render
				$out += "`n"
                }
			}
        }
	    $out
	} else
	{
		write-error "Cannot load template file [$templatefile] or it is empty"
	} 
}

function Get-BuildDataSet
{
param
(
    $tfsUri,
    $teamproject,
    $buildid,
    $usedefaultcreds
  )

 	write-verbose "Getting build details for BuildID [$buildid]"    
 	$build = Get-Build -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds

     $build = @{'build'=$build;
                'workitems'=(Get-BuildWorkItems -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds);
                'changesets'=(Get-BuildChangeSets -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds )}
    $build
 }

function Get-ReleaseByDefinitionId
{

    param
    (
    $tfsUri,
    $teamproject,
    $releasedefid,
    $usedefaultcreds
    )

    Write-Verbose "Getting details of release by definition [$releasedefid] from server [$tfsUri/$teamproject]"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up   
	$rmtfsUri = $tfsUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases?definitionId=$($releasedefid)&`$Expand=environments,artifacts&queryOrder=descending&api-version=3.0-preview"

  	$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
  	$jsondata.value
}

# types to make the switches neater
Add-Type -TypeDefinition @"
   public enum Mode
   {
      BODY,
      WI,
      CS,
      BUILD
   }
"@


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
	
	# for backwards compibility we need the $release set the tiggering release
    # if this is not done any old templates break
    $release = $releases[0]
	# also for backwards compibiluty we swap the hash table for a simple array in build create order (we assume buildID is incrementing)
	$builds = $($buildsList.GetEnumerator() | Sort-Object { $_.Value.build.id }).Value
}

$template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
$outputmarkdown = Process-Template -template $template -builds $builds

write-Verbose "Writing output file [$outputfile]."
Set-Content $outputfile $outputmarkdown

if ([string]::IsNullOrEmpty($outputvariablename))
{
    write-Verbose "Skipping setting output variable name as parameter was not set."
} 
else 
{    
    Write-Verbose "Setting variable: [$outputvariablename] = $outputmarkdown" -Verbose
    Write-Host ("##vso[task.setvariable variable=$outputvariablename;]$outputmarkdown")
}



