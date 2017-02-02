##-----------------------------------------------------------------------
## <copyright file="Create-ReleaseNotes.psm1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Library ysed to create as a Markdown Release notes file for a build froma template file
#
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
    $wiList = @();
   
    try {
        $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0"
  	    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds| ConvertFrom-Json
   	    foreach ($wi in $jsondata.value)
        {
            $wiList += Get-Detail -uri $wi.url -usedefaultcreds $usedefaultcreds
        } 
    }
    catch {
            Write-warning "Unable to get associated work items, most likely cause is the build has been deleted"
            Write-warning $_.Exception.Message
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
  	$csList = @();

    try 
    { 
        $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0"
        $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
        foreach ($cs in $jsondata.value)
        {
        # we can get more detail if the changeset is on VSTS or TFS
        try {
            $csList += Get-Detail -uri $cs.location -usedefaultcreds $usedefaultcreds
        } catch
        {
            Write-warning "Unable to get details of changeset/commit as it is not stored in TFS/VSTS"
            Write-warning "For [$($cs.id)] location [$($cs.location)]"
            Write-warning "Just using the details we have from the build"
            $csList += $cs
        }
        }
    } catch 
    {
            Write-warning "Unable to get details of changeset/commit, most likely cause is the build has been deleted"
            Write-warning $_.Exception.Message
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

function Add-Space
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
		
    # following line would be the obvious choice but it is buggy in V4 seems ok in older and newer
	# so we have to use invoke-expression
    #$ExecutionContext.InvokeCommand.ExpandString($str)

	#also we have to use the complex handler so make sure we catch errors in executed lines
 	Try{
       $output = (Invoke-Expression -Command "@`"`n$str`n`"@" ) 2>&1
 	   if ($lastexitcode) {throw $output}
	   $output
    } Catch{
      write-verbose $output
	}
    
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

function Add-StackItem
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
    Write-Verbose "$(Add-Space -indent ($modeStack.Count +1))$($queue.Count) items"
    # place it on the stack with the blocks mode and start line index
    $modeStack.Push(@{'Mode'= $mode;
                      'BlockQueue'=$queue;
                      'Index' = $index})
}

function Invoke-Template 
{
	Param(
	  $template,
      $releases,
      $builds,
      $stagename
	)
	
	if ($template.count -gt 0)
	{
		write-Verbose "Processing template"
		write-verbose "There are [$(@($builds).count)] builds to process"

        # create our work stack and initialise
		$modeStack = new-object  System.Collections.Stack 
		$modeStack.Push([Mode]::BODY)
		
        # this line is to provide support the the legacy build only template
        # if using a release template it will be reset when processing tags
        $builditem = $builds
		$build = $builditem.build # using two variables for legacy support

        # for backwards compibility we need the $release set to the tiggering release
        # if this is not done any old may templates break
        if ($releases -ne $null)
        {
            write-verbose "From [$(@($releases).count)] releases"
            $release = @($releases)[0]
        }
	
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
                            Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting next workitem $($item.id)"
		                    $widetail = $item  
                            }
                          "CS" {
                            Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting next changeset/commit $($item.id)"
		                    $csdetail = $item 
                            }
                          "BUILD" {
                            Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting next build $($item.build.id)"
		                    $builditem = $item
                            $build = $builditem.build # using two variables for legacy support
                            }
                         } #end switch
                    }
                    else
                    {
                        # end of block and no more items, so exit the block
                        $mode = $modeStack.Pop().Mode
                        Write-Verbose "$(Add-Space -indent $modeStack.Count)Ending block $mode"
                    }
                } else {
                    # this a new block to add the stack
                    # need to get the items to process and place them in a queue
                    Write-Verbose "$(Add-Space -indent ($modeStack.Count))Starting block $($mode)"
           
                    #set the index to jump back to
                    $lastBlockStartIndex = $index       
                    switch ($mode)
			        {
			            "WI" {
                            # store the block and load the first item
                            Add-StackItem -items @($builditem.workItems) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                                $widetail = $modeStack.Peek().BlockQueue.Dequeue()
                                Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first workitem $($widetail.id)"
                            } else {
                                $widetail = $null
                            }
                         }
                         "CS" {
                            # store the block and load the first item
                            Add-StackItem -items @($builditem.changesets) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                               $csdetail = $modeStack.Peek().BlockQueue.Dequeue()   
                               Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first changeset/commit $($csdetail.id)"
		                    
                            } else {
                                $csdetail = $null
                            }
                                                      
                         }
                        "BUILD" {
                            Add-StackItem -items @($builds) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0)
                            {
                               $builditem = $modeStack.Peek().BlockQueue.Dequeue() 
                               $build = $builditem.build
                               Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first build $($build.id)"
		                   
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
                } else 
			    {
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
 	$build = Get-Build -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds

     $build = @{'build'=$build;
                'workitems'=(Get-BuildWorkItems -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds);
                'changesets'=(Get-BuildChangeSets -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds )}
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