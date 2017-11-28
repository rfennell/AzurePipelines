function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Error "`n$message"
    }
}

function Show-InputParameters
{
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabVMId = $LabVMId"
}

function Invoke-AzureStopTask
{
    [CmdletBinding()]
    param(
        $LabVMId
    )

    $labVMParts = $LabVMId.Split('/')
    $labVMName = $labVMParts.Get($labVMParts.Length - 1)
    $labName = $labVMParts.Get($labVMParts.IndexOf('labs') + 1)

    Write-Host "Starting Lab VM '$labVMName' from Lab '$labName'"

    Invoke-AzureRmResourceAction -ResourceId $LabVMId -Action Stop -Force | Out-Null
}
