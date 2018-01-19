##-----------------------------------------------------------------------
## <copyright file="Create-ReleaseNotes.psm1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Library ysed to create as a Markdown Release notes file for a build froma template file
#
Import-Module -Name "$PSScriptRoot\Get-CallerPreference.ps1" -Force 

function Get-BuildWorkItems {
    param
    (
        $tfsUri,
        $teamproject,
        $buildid,
        $usedefaultcreds,
        $maxItems,
        $wifilter,
		$wiStateFilter,
		$showParents
    )

    Write-Verbose "        Getting up to $($maxItems) associated work items for build [$($buildid)]"
    $wiList = @();
	 
    try {
        $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0&`$top=$($maxItems)"
		$jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds| ConvertFrom-JsonUsingDOTNET
		Write-Verbose "        Found $($jsondata.value.Count) WI directly associated with build"
		if ($showParents -eq $false)
		{
			Write-Verbose "        Running in directly associated WI only mode"
			foreach ($wi in $jsondata.value) {
				$wiList += Get-Detail -uri $wi.url -usedefaultcreds $usedefaultcreds
			}	
		} else {
            $wiArray = @{}
			Write-Verbose "        Running in directly associated WI and parent mode"
			foreach ($wi in $jsondata.value) {
				# Get associated work item
				$wiuri = $wi.url
				$wiuri = "$($wiuri)?`$expand=relations"
				$wiDetail = Get-Detail -uri $wiuri -usedefaultcreds $usedefaultcreds
				$wiArray.Add($wiDetail.id, $wiDetail)
				$wiType = $wiDetail.fields."System.WorkItemType"
				if ("Task,Bug" -like "*$wiType*") {
					# Get parent work item (for Task and Bug only)
					foreach ($parentwi in $wiDetail.relations) {
						if ($parentwi.rel -eq "System.LinkTypes.Hierarchy-Reverse") {
							$wiParent = Get-Detail -uri $parentwi.url -usedefaultcreds $usedefaultcreds
							if ($wiArray.ContainsKey($wiParent.id) -eq $false) {
								$wiArray.Add($wiParent.id, $wiParent)
							}
						}
					}
				}
            }
            Write-Verbose "        Found $($wiArray.Count) WI directly associated with build or parents of associated WI before filtering"

			# Filter the wi's based on types
			$keys = @($wiArray.Keys)
			if (([string]::IsNullOrEmpty($wifilter) -eq $false)) {
				Write-Verbose "        Filtering WI on type - $($wifilter)"
				foreach ($key in $keys) {
					$wi = $wiArray.$key
					$wiType = $wi.fields."System.WorkItemType"
					if ($wifilter -notlike "*$wiType*") {
                        Write-Verbose "        Removed WI $($key) as does not match type filter"
						$wiArray.Remove($key)
					}
				}
			}
			# Filter the wi's based on states
			$keys = @($wiArray.Keys)
			if (([string]::IsNullOrEmpty($wiStateFilter) -eq $false)) {
				Write-Verbose "        Filtering WI on state - $($wiStateFilter)"
				foreach ($key in $keys) {
					$wi = $wiArray.$key
					$wiState = $wi.fields."System.State"
					if ($wiStateFilter -notlike "*$wiState*") {
                        Write-Verbose "        Removed WI $($key) as does not match state filter"
						$wiArray.Remove($key)
					}
				}
			}
			# Now get the resulting array
			$wiList = @($wiArray.Values)
		}
    }
    catch {
        Write-warning "        Unable to get associated work items, most likely cause is the build has been deleted"
        Write-warning $_.Exception.Message
    }
    $wiList
}

function Get-BuildChangeSets {
    param
    (
        $tfsUri,
        $teamproject,
        $buildid,
        $usedefaultcreds,
        $maxItems
    )

    Write-Verbose "        Getting up to $($maxItems) associated changesets/commits for build [$($buildid)]"
    $csList = @();

    try { 
        $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0&`$top=$($maxItems)"
        $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
        foreach ($cs in $jsondata.value) {
            if (!$cs.message) {continue} # skip commits with no description
            # we can get more detail if the changeset is on VSTS or TFS
            try {
                $csList += Get-Detail -uri $cs.location -usedefaultcreds $usedefaultcreds
            }
            catch {
                Write-warning "        Unable to get details of changeset/commit as it is not stored in TFS/VSTS"
                Write-warning "        For [$($cs.id)] location [$($cs.location)]"
                Write-warning "        Just using the details we have from the build"
                $csList += $cs
            }
        }
    }
    catch {
        Write-warning "        Unable to get details of changeset/commit, most likely cause is the build has been deleted"
        Write-warning $_.Exception.Message
    }
    $csList
}

function Get-Detail {
    param
    (
        $uri,
        $usedefaultcreds
    )

    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
    $jsondata
}

function Get-Build {

    param
    (
        $tfsUri,
        $teamproject,
        $buildid,
        $usedefaultcreds
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)?api-version=2.0"
    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
    $jsondata 
}

function Get-BuildsByDefinitionId {

    param
    (
        $tfsUri,
        $teamproject,
        $buildDefid,
        $usedefaultcreds
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?definitions=$($builddefid)&api-version=2.0"
    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
    $jsondata.value
}

function Get-ReleaseDefinitionByName {
    param
    (
        $tfsUri,
        $teamproject,
        $releasename,
        $usedefaultcreds  
    )
	
    $uri = "$($tfsUri)/$($teamproject)/_apis/release/definitions?api-version=3.0-preview.1"
    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
    $jsondata.value | where { $_.name -eq $releasename  }

}

function Get-Release {

    param
    (
        $tfsUri,
        $teamproject,
        $releaseid,
        $usedefaultcreds
    )

    Write-Verbose "Getting details of release [$releaseid] from server [$tfsUri/$teamproject]"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up   
    $rmtfsUri = $tfsUri -replace ".visualstudio.com", ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseid)?api-version=3.0-preview"

    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
    $jsondata
}

function Get-BuildReleaseArtifacts {

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

function ConvertFrom-JsonUsingDOTNET {
    param
    (
      [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
      $data,
      [int]$maxdatasize = 104857600 #100mb as bytes, default is 2mb
    )
 
    add-type -assembly system.web.extensions
    # Work around on
    # ConvertFrom-Json : Error during serialization or deserialization using the JSON JavaScriptSerializer. The length of the string exceeds the value set on the maxJsonLength property.
 
    $json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $json.MaxJsonLength = $maxdatasize
 
    $jsonTree = $json.Deserialize($data, [System.Object])
    Expand-Tree $jsonTree $jsondata.count
 }
 
 function Expand-Tree($jsonTree) {
     $result = @()
 
     # Go through each node in the tree
     foreach ($node in $jsonTree) {
 
         # For each node we need to set up its keys/properties/fields
         $nodeHash = @{}
         foreach ($property in $node.Keys) {
             # If a field is a set (either a dictionary or array - both used by the deserializer) we will need to iterate it
             if ($node[$property] -is [System.Collections.Generic.Dictionary[String, Object]] -or $node[$property] -is [Object[]]) {
                 # This assignment is important as it forces single result sets to be wrapped in an array, which is required
                 $inner = @()
                 $inner += Expand-Tree $node[$property]
 
                 $nodeHash.Add($property, $inner)
             } else {
                 $nodeHash.Add($property, $node[$property])
             }
         }
 
         # Create a custom object from the hash table so it matches the original. It must be a PSCustomObject
         # because the serializer (later) requires that and not a PSObject or HashTable.
         $result += [PSCustomObject] $nodeHash
     }
 
     return $result
 }

function Add-Space {
    param(
        $size = 3,
        $indent = 1
			 )
		
    $upperBound = $size * $indent
    for ($i = 1 ; $i -le $upperBound  ; $i++) {
        $padding += " "
    } 
    $padding
}

function Invoke-GetCommand {
    [CmdletBinding()]
    param
    (
        $uri,
        $usedefaultcreds
    )

    # When debugging locally, this variable can be set to use personal access token.
    $debugpat = $env:PAT

    $webclient = new-object System.Net.WebClient
    $webclient.Encoding = [System.Text.Encoding]::UTF8
	
    if ([System.Convert]::ToBoolean($usedefaultcreds) -eq $true) {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    } 
    elseif (([string]::IsNullOrEmpty($debugpat) -eq $false) -and ($DebugPreference -eq "Inquire")) {
        $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$debugpat"))
        $webclient.Headers.Add("Authorization", "Basic $encodedPat")
    }
    else {
        # Write-Verbose "Using SystemVssConnection personal access token"
        $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
        $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
        $webclient.Headers.Add("Authorization" , "Bearer $personalAccessToken")
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
    Try {
        $output = (Invoke-Expression -Command "@`"`n$str`n`"@" ) 2>&1
        if ($lastexitcode) {throw $output}
        $output
    }
    Catch {
        write-verbose "RENDER ERROR: cannot process [$str]"
        write-verbose $output
    }
		
}

function Get-Template {
    param (
        $templateLocation,
        $templatefile,
        $inlinetemplate
    )
	
    Write-Verbose "Using template mode [$templateLocation]"

    if ($templateLocation -eq 'File') {
        write-Verbose "Loading template file [$templatefile]"
        $template = Get-Content $templatefile
    }
    else {
        write-Verbose "Using in-line template"
        # it appears as single line we need to split it out
        $template = $inlinetemplate -split "`n"
    }
	
    $template
}

function Get-Mode {
    Param(
        $line
    )

    $mode = [Mode]::BODY
    if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::WI}
    if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::CS}
    if ($line.Trim() -eq "@@BUILDLOOP@@") {$mode = [Mode]::BUILD}
    $mode
}

function Add-StackItem {

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
    foreach ($item in @($items)) {
        $queue.Enqueue($item)
    }
    Write-Verbose "$(Add-Space -indent ($modeStack.Count +1))$($queue.Count) items"
    # place it on the stack with the blocks mode and start line index
    $modeStack.Push(@{'Mode' = $mode;
            'BlockQueue' = $queue;
            'Index' = $index
        })
}

function Invoke-Template {
    Param(
        $template,
        $releases,
        $builds,
        $stagename,
        $defname,
        $releasedefname
    )
	
    if ($template.count -gt 0) {
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
        if ($releases -ne $null) {
            write-verbose "From [$(@($releases).count)] releases"
            $release = @($releases)[0]
        }
	
        #process each line
        For ($index = 0; $index -lt $template.Count; $index++) {
            $line = $template[$index]
            # get the line change mode if any
            $mode = Get-Mode -line $line

            #debug logging
            #Write-Verbose "$Index[$($mode)]: $line"

            if ($mode -ne [Mode]::BODY) {
                # is there a mode block change
                if ($modeStack.Peek().Mode -eq $mode) {
                    # this means we have reached the end of a block
                    # need to work out if there are more items to process 
                    # or the end of the block
                    $queue = $modeStack.Peek().BlockQueue;
                    if ($queue.Count -gt 0) {
                        # get the next item and initialise
                        # the variables exposed to the template
                        $item = $queue.Dequeue()
                        # reset the index to process the block
                        $index = $modeStack.Peek().Index
                        switch ($mode) {
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
                    else {
                        # end of block and no more items, so exit the block
                        $mode = $modeStack.Pop().Mode
                        Write-Verbose "$(Add-Space -indent $modeStack.Count)Ending block $mode"
                    }
                }
                else {
                    # this a new block to add the stack
                    # need to get the items to process and place them in a queue
                    Write-Verbose "$(Add-Space -indent ($modeStack.Count))Starting block $($mode)"
					 
                    #set the index to jump back to
                    $lastBlockStartIndex = $index       
                    switch ($mode) {
                        "WI" {
                            # store the block and load the first item
                            Add-StackItem -items @($builditem.workItems) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0) {
                                $widetail = $modeStack.Peek().BlockQueue.Dequeue()
                                Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first workitem $($widetail.id)"
                            }
                            else {
                                $widetail = $null
                            }
                        }
                        "CS" {
                            # store the block and load the first item
                            Add-StackItem -items @($builditem.changesets) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0) {
                                $csdetail = $modeStack.Peek().BlockQueue.Dequeue()   
                                Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first changeset/commit $($csdetail.id)"
												
                            }
                            else {
                                $csdetail = $null
                            }
																											
                        }
                        "BUILD" {
                            Add-StackItem -items @($builds) -modeStack $modeStack -mode $mode -index $index
                            if ($modeStack.Peek().BlockQueue.Count -gt 0) {
                                $builditem = $modeStack.Peek().BlockQueue.Dequeue() 
                                $build = $builditem.build
                                Write-Verbose "$(Add-Space -indent $modeStack.Count)Getting first build $($build.id)"
											 
                            }
                            else {
                                $builditem = $null
                                $build = $null
                            }
                        }
                    }
                }
            }
            else {
                if ((($modeStack.Peek().mode -eq [Mode]::WI) -and ($widetail -eq $null)) -or 
                    (($modeStack.Peek().mode -eq [Mode]::CS) -and ($csdetail -eq $null))) {
                    # there is no data to expand
                    $out += $emptySetText
                }
                else {
                    # nothing to expand just process the line
                    $out += $line | render
                    $out += "`n"
                }
            }
        }
        $out
    }
    else {
        write-error "Cannot load template file [$templatefile] or it is empty"
    } 
}

function Get-BuildDataSet {
    [CmdletBinding()]
    param
    (
        $tfsUri,
        $teamproject,
        $buildid,
        $usedefaultcreds,
        $maxWi,
        $maxChanges,
        $wiFilter,
		$wiStateFilter,
		$showParents
    )

    # Get the callers preference variables. See https://blogs.technet.microsoft.com/heyscriptingguy/2014/04/26/weekend-scripter-access-powershell-preference-variables/
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    write-verbose "    Getting build details for BuildID [$buildid]"    
    $build = Get-Build -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds

    $build = @{ 'build' = $build;
				'workitems' = (Get-BuildWorkItems -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -maxItems $maxWi -wifilter $wifilter -wiStateFilter $wiStateFilter -showParents $showParents);
				'changesets' = (Get-BuildChangeSets -tfsUri $tfsUri -teamproject $teamproject -buildid $buildid -usedefaultcreds $usedefaultcreds -maxItems $maxChanges )
    }
    $build
}

function Get-ReleaseByDefinitionId {

    param
    (
        $tfsUri,
        $teamproject,
        $releasedefid,
        $usedefaultcreds
    )

    Write-Verbose "Getting details of release by definition [$releasedefid] from server [$tfsUri/$teamproject]"

    # at present Jun 2016 this API is in preview and in different places in VSTS hence this fix up   
    $rmtfsUri = $tfsUri -replace ".visualstudio.com", ".vsrm.visualstudio.com/defaultcollection"
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases?definitionId=$($releasedefid)&`$Expand=environments,artifacts&queryOrder=descending&api-version=3.0-preview"

    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-JsonUsingDOTNET
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
