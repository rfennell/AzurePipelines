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
    $templatefile  
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
  	$jsondata.value 
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
  	$jsondata.value 

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
    $defid,
    $buildnumber
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&buildnumber=$($buildnumber)"
  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
  	$jsondata.value 
}

function Get-BuildDefinitionId
{
    param
    (
    $tfsUri,
    $teamproject,
    $defname
    )

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0&name=$($defname)"
  	$jsondata = Invoke-GetCommand -uri $uri | ConvertFrom-Json
  	$jsondata.value.id 

}

function Invoke-GetCommand
{
    param
    (
     $uri
    )
    $vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
    $personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
	$headers = @{Authorization = "Bearer $personalAccessToken"}
    Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing
}

function render() {
    [CmdletBinding()]
    param ( [parameter(ValueFromPipeline = $true)] [string] $str)

    #buggy in V4 seems ok in older and newer
    #$ExecutionContext.InvokeCommand.ExpandString($str)

    "@`"`n$str`n`"@" | iex
}

$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$buildid = $env:BUILD_BUILDID
$defname = $env:BUILD_DEFINITIONNAME
$buildnumber = $env:BUILD_BUILDNUMBER

Write-Verbose "Getting details of build [$defname] from server [$collectionUrl/$teamproject]"
$defId = Get-BuildDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -defname $defname 
write-verbose "Getting build number [$buildnumber] using definition ID [$defId]"    
$build = Get-Build -tfsUri $collectionUrl -teamproject $teamproject -defid $defId -buildnumber $buildnumber

Write-Verbose "Getting associated work items"
$workitems = Get-BuildWorkItems -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid 
Write-Verbose "Getting associated changesets/commits"
$changesets = Get-BuildChangeSets -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid 

$template = Get-Content $templatefile
Add-Type -TypeDefinition @"
   public enum Mode
   {
      BODY,
      WI,
      CS
   }
"@
$mode = [Mode]::BODY
#process each line
ForEach ($line in $template)
{
    # work out if we need to loop on a blog
    #Write-Verbose "Processing line [$line]"
    if ($mode -eq [Mode]::BODY)
    {
        if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::WI; continue}
        if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::CS; continue}
    } else {
        if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::BODY; continue}
        if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::BODY; continue}
    }

    switch ($mode)
    {
      "WI" {
        foreach ($wi in $workItems)
        {
           # Get the work item details so we can render the line
           Write-Verbose "   Get details of workitem $($wi.id)"
           $widetail = Get-Detail -uri $wi.url  
           $out += $line | render
           $out += "`n"
        }
        continue
        }
      "CS" {
        foreach ($cs in $changesets)
        {
           # we can get enough detail from the list of changes
           Write-Verbose "   Get details of changeset/commit $($cs.id)"
           $csdetail = Get-Detail -uri $cs.location 
           $out += $line | render
           $out += "`n"
        }
        continue
        }
     "BODY" {
            # nothing to expand just process the line
            $out += $line | render
            $out += "`n"
        }
    }
}
write-Verbose "Writing output file [$outputfile] for build [$defname] [$($build.buildNumber)]."
Set-Content $outputfile $out



