###################################################################################################

#
<##################################################################################################

    Description
    ===========

	Start a Lab VM given its resource ID.

    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Parameters to this script file are read using Get-VstsInput
#

[CmdletBinding()]
Param(
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

###################################################################################################

#
# Functions used in this script.
#

.".\task-funcs.ps1"

###################################################################################################

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    Write-Host 'Starting Azure DevTest Labs Start VM Task'

	# Get the parameters
	$ConnectedServiceName = Get-VstsInput -Name "ConnectedServiceName"
	$LabVMId = Get-VstsInput -Name "LabVMId"

    Show-InputParameters
	
	# Get the end point
	$Endpoint = Get-VstsEndpoint -Name $ConnectedServiceName -Require

    # Get the Authentication
    $clientID = $Endpoint.Auth.parameters.serviceprincipalid
    $key = $Endpoint.Auth.parameters.serviceprincipalkey 
	$tenantId = $Endpoint.Auth.parameters.tenantid
	
    $SecurePassword = $key | ConvertTo-SecureString -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $clientID, $SecurePassword

	# Authenticate
    Login-AzureRmAccount -Credential $cred -TenantId $tenantId -ServicePrincipal
	
    Invoke-AzureStartTask -LabVMId "$LabVMId"

    Write-Host 'Completing Azure DevTest Labs Start VM Task'
}
finally
{
    popd
}
