[CmdletBinding()]
param
(
)

#DEBUG Invoke-Request
#function Invoke-WebRequest
#{
#    param(
#        $Username,
#        $password,
#        $account,
#        $ProjectName,
#        $ApiUrl
#    )
#
#
#    Add-Type -AssemblyName System.Net.Http
#    $RequestHandler = New-Object -TypeName System.Net.Http.HttpClientHandler
#    $Request =  New-Object -TypeName System.Net.Http.HttpClient $RequestHandler
#    $DefaultRequestHeaderContentType = New-Object -TypeName System.Net.Http.Headers.MediaTypeWithQualityHeaderValue "application/json"
#    $TextToEncode = [System.String]::Format("{0}:{1}",$Username, $Password)
#    $Text = [System.Text.ASCIIEncoding]::ASCII.GetBytes($TextToEncode)
#    $Base64String = [System.Convert]::ToBase64String($Text)
#    $DefaultRequestHeaderAuthType = New-Object System.Net.Http.Headers.AuthenticationHeaderValue -ArgumentList "Basic", $Base64String
#    $Request.DefaultRequestHeaders.Accept.Add($DefaultRequestHeaderContentType)
#    $Request.DefaultRequestHeaders.Authorization = $DefaultRequestHeaderAuthType
#    $BaseUrl = "https://dev.azure.com/$($account)/$($ProjectName)/$($ApiUrl)"
#    $Request.BaseAddress = $BaseUrl
#    $Response = $Request.GetAsync($BaseUrl).Result.Content.ReadAsStringAsync().Result
#    $Response  = $Response | ConvertFrom-Json
#    $Request.Dispose()
#    $Response
#}
function Get-WebClient
{
    param
    (
       $usedefaultcreds
    )

    $webclient = new-object System.Net.WebClient

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

    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $webclient.Headers["Content-Type"] = "application/json"
    $webclient

}
function Get-BuildDefinition
{
    param
    (
        $tfsuri,
        $teamproject,
        $buildDefName,
        $usedefaultcreds
    )
    Write-Verbose "Function: Get-BuildDefinition Parameters"
    Write-Verbose "tfsUri: $tfsuri"
    Write-Verbose "teamProject: $teamproject"
    Write-Verbose "buildDefinitionName: $buildDefName"
    
    $webclient = Get-WebClient -usedefaultcreds $usedefaultcreds

    write-verbose "Getting Build Definition $buildDefName "

    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0"

    Write-Verbose "Initiating GET Request to URI: $uri"
    $definitionsResponse = $webclient.DownloadString($uri) | ConvertFrom-Json
    #DEBUG
    #$definitionsResponse = Invoke-WebRequest -Username $Username -password $password -account $account -ProjectName $teamproject -ApiUrl "_apis/build/definitions?api-version=2.0"
    Write-Verbose "DEFINITIONS RESPONSE: $webclient"
    if($null -ne $webclient){
        $definition = ($definitionsResponse.value | Where-Object {$_.Name -eq $buildDefName})
    
        if($null -ne $definition ){
            $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions/$($definition.id)?api-version=4.0"
            Write-Verbose "Initiating GET Request to URI: $uri"
            $buildResponse = $webclient.DownloadString($uri) | ConvertFrom-Json
            
            #DEBUG
            #$buildResponse = Invoke-WebRequest -Username $Username -password $password -account $account -ProjectName $teamproject -ApiUrl "_apis/build/definitions/$($definition.id)?api-version=4.0"
            Write-Verbose "DEFINITION RESPONSE: $buildResponse"
            return $buildResponse
            
           
        }
        if ($null -eq $definition ) {
            Write-Verbose "Failed to find the specified definition $buildDefName."
        }
    }
    if($null -eq $response){
        Write-Verbose "Failed to retrieve list of build definitions from $tfsuri"
    }
}

function Update-CurrentScopeVariable
{
    Param(
        $tfsuri,
        $teamproject,
        $builddefname,
        $variable,
        $localVariable,
        $usedefaultcreds
      )
    # get the old definition
    Write-Verbose "Function: Update-CurrentScopeVariable"
    Write-Verbose "tfsUri: $tfsuri"
    Write-Verbose "teamProject: $teamproject"
    Write-Verbose "buildDefinitionName: $builddefname"
    Write-Verbose "remoteVariable: $variable"
    Write-Verbose "localVariable: $localVariable"
    Write-Verbose "usingDefaultCreds: $usedefaultcreds"

    $def = Get-BuildDefinition -tfsuri $tfsuri -teamproject $teamproject -buildDefName $builddefname -usedefaultcreds $usedefaultcreds
    if($null -ne $def)
    {
        Write-Verbose "Found definition $def"
        $foundGroup = $null
        $item = $null
        if ($variable -in $def.variables.PSobject.Properties.Name)
        {
            Write-Verbose "Current value of the pipeline variable [$variable] is [$($def.variables.$variable.value)]"
            $value = "$($def.variables.$variable.value)"
        } if($variable -notin $def.variables.PSobject.Properties.Name) {
            Write-verbose "Variable is not found as a pipeline variable"
            # check if there is a variable group
            foreach ($group in $def.variableGroups)
            {
                Write-verbose "Checking for variable in $($group.name)"
                if ($variable -in $group.variables.PSobject.Properties.Name)
                {
                    write-verbose "group details $group"
                    Write-Verbose "Current value of the variable [$variable] is [$($group.variables.$variable.value)] in [$($group.name)] with ID [$($group.id)]"
                    $item =$group.variables.$variable
                    $foundGroup = $group
                    break
                }
            }
        }
        Write-Output ("##vso[task.setvariable variable=$localVariable;]$value")
    }
}

# Output execution parameters.
$VerbosePreference ='Continue' # equiv to -verbose

# Get the build details
$collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$teamproject = $env:SYSTEM_TEAMPROJECT
$builddefid = $env:BUILD_DEFINITIONID

#DEBUG ONLY
#$Username = "anyvalue"
#$password = "a PAT token"
#$ProjectName = "TEAM PROJECT NAME"
#$account  = "The account name"
#$teamproject

Write-Verbose "collectionUrl = [$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI]"
Write-Verbose "teamproject = [$env:SYSTEM_TEAMPROJECT]"
Write-Verbose "builddefid = [$env:BUILD_DEFINITIONID]"
Write-Verbose "usedefaultcreds = $usedefaultcreds"

Write-Verbose "Parameters"
Write-Verbose "$builddefinitionname"
Write-Verbose "$variable"
Write-Verbose "$localVariable"

Write-Verbose ("Getting the variable from specified definition.")
Update-CurrentScopeVariable -tfsuri $collectionUrl -teamproject $teamproject -builddefname $builddefinitionname -variable $variable -localVariable $localVariable -usedefaultcreds $usedefaultcreds

