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
    $templatefile,
    
    $token
  
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

function Get-WebClient
{
 param
    (
        [string]$username, 
        [string]$password,
        [string]$ContentType = "application/json"
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = $ContentType
    
    if ([System.String]::IsNullOrEmpty($password))
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
       # This is the form for basic creds so either basic cred (in TFS/IIS) or alternate creds (in VSTS) are required"
       # or just pass a personal access token in place of a password
       $pair = "${username}:${password}"
       $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
       $base64 = [System.Convert]::ToBase64String($bytes)
       $wc.Headers.Add("Authorization","Basic $base64");
    }
    $wc
}


function Get-BuildWorkItems
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0"
    
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value
}

function Get-BuildChangeSets
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value 
}


function Get-WorkItemDetail
{
    param
    (
    $url,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $jsondata = $wc.DownloadString($url) | ConvertFrom-Json 
    $jsondata 
}

function Get-Build
{

    param
    (
    $tfsUri,
    $teamproject,
    $defid,
    $buildnumber,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&buildnumber=$($buildnumber)"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value
}

function Get-BuildDefinitionId
{

    param
    (
    $tfsUri,
    $teamproject,
    $defname,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0&name=$($defname)"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value.id 

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
$defId = Get-BuildDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -defname $defname  -password $token
write-verbose "Getting build number [$buildnumber] using definition ID [$defId]"    
$build = Get-Build -tfsUri $collectionUrl -teamproject $teamproject -defid $defId -buildnumber $buildnumber -password $token

Write-Verbose "Getting associated work items"
$workitems = Get-BuildWorkItems -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid  -password $token
Write-Verbose "Getting associated changesets/commits"
$changsets = Get-BuildChangeSets -tfsUri $collectionUrl -teamproject $teamproject -buildid $buildid -password $token

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
    if ($mode -eq [Mode]::BODY)
    {
        if ($line -eq "@@WILOOP@@") {$mode = [Mode]::WI; continue}
        if ($line -eq "@@CSLOOP@@") {$mode = [Mode]::CS; continue}
    } else {
        if ($line -eq "@@WILOOP@@") {$mode = [Mode]::BODY; continue}
        if ($line -eq "@@CSLOOP@@") {$mode = [Mode]::BODY; continue}
    }

    switch ($mode)
    {
      "WI" {
        foreach ($wi in $workItems)
        {
           # Get the work item details
           Write-Verbose "   Get details of workitem $($wi.id)"
           $widetail = Get-WorkItemDetail -url $wi.url -password $token 
           $out += $line | render
        }
        continue
        }
      "CS" {
        foreach ($csdetail in $changsets)
        {
           # we can get enough detail from the list of changes
           Write-Verbose "   Get details of changeset/commit $($csdetail.id)"
           $out += $line | render
        }
        continue
        }
     "BODY" {
        # nothing to expand just process the line
        $out += $line | render
        }
    }
}
write-Verbose "Writing output file $reportname for build [$defname] [$($build.buildNumber)]."
Set-Content $outputfile $out



