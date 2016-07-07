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

    [parameter(Mandatory=$false,HelpMessage="The markdown template file")]
    $templatefile ,
	
    [parameter(Mandatory=$false,HelpMessage="The inline markdown template")]
    $inlinetemplate, 
	
	[parameter(Mandatory=$false,HelpMessage="Location of markdown template")]
    $templateLocation 
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

function Get-BuildWorkItems
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
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
    $buildid
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
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
    $uri
    )

  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
  	$jsondata
}

function Get-Build
{

    param
    (
    $tfsUri,
    $teamproject,
    $buildid
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)?api-version=2.0"
  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
  	$jsondata 
}

function Get-Release
{

    param
    (
    $tfsUri,
    $teamproject,
    $releaseid
    )

    Write-Verbose "Getting details of release [$releaseid] from server [$tfsUri/$teamproject]"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up   
	$rmtfsUri = $tfsUri -replace ".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseid)?api-version=3.0-preview"

  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
  	$jsondata
}

function Get-BuildIDsRelease
{

    param
    (
    $tfsUri,
    $teamproject,
    $release
    )

	# get the build IDs
    $buildIds = $release.artifacts.definitionReference.version.id
	$buildIds
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
     $uri
    )
    $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
    $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
    $webclient = new-object System.Net.WebClient
    $webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
    $webclient.Encoding = [System.Text.Encoding]::UTF8
	
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
                $out += "None"
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
    $buildid
  )

 	write-verbose "Getting build details for BuildID [$buildid]"    
 	$build = Get-Build -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid

    Write-Verbose "Getting associated work items for build [$($buildid)]"
	Write-Verbose "Getting associated changesets/commits for build [$($buildid)]"

    $build = @{'build'=$build;
                'workitems'=(Get-BuildWorkItems -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid);
                'changesets'=(Get-BuildChangeSets -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid )}
    $build
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
$buildid = $env:BUILD_BUILDID
$defname = $env:BUILD_DEFINITIONNAME
$buildnumber = $env:BUILD_BUILDNUMBER

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "releaseid = [$env:RELEASE_RELEASEID]"
Write-Verbose "buildid = [$env:BUILD_BUILDID]"
Write-Verbose "defname = [$env:BUILD_DEFINITIONNAME]"
Write-Verbose "buildnumber = [$env:BUILD_BUILDNUMBER]"


if ( [string]::IsNullOrEmpty($releaseid))
{
    
   Write-Verbose "In Build mode"
   $builds = Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid
    
} else
{
	Write-Verbose "In Release mode"
    $release = Get-Release -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseid
	# we put all the work items and changesets into an array associated with their build
    $builds = @()
  	foreach ($buildId in (Get-BuildIDsRelease -tfsUri $collectionUrl -teamproject $teamproject -release $release))
	{
		$builds += Get-BuildDataSet -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid
	}
}

$template = Get-Template -templateLocation $templateLocation -templatefile $templatefile -inlinetemplate $inlinetemplate
$outputmarkdown = Process-Template -template $template -builds $builds

write-Verbose "Writing output file [$outputfile]."
Set-Content $outputfile $outputmarkdown



