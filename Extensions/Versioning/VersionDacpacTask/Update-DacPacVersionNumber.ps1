<#
.Synopsis
    Updates the version of a specified DACPAC file.
.DESCRIPTION
    This script will update the version number of a specifed DACPAC file using the SQL DacPackage
    namespace methods. Catches any errors that occur on the versioning section and uses Write-Warning
    to output what went wrong, this is to prevent the whole build failing because it can't version some files
    which haven't been versioned perviously. 

    Any errors which are thrown by the DLLs not being available will return -1 exit code which will stop the build
    process however (as it's likely to cause other problems with those DLLs not being available).

.PARAMETER Path
    Path to the folder holding the DACPAC files

.PARAMETER VersionNumber
    Version Number to update each DACPAC with, must be a string format but will be handled by PS into correct Version object.

.EXAMPLE
    Update-DacpacVersionNumber.ps1 -Path C:\DacFolder -VersionNumber 1.3.53

    This will get each DACPAC file within the C:\DacFolder and apply version 1.3.53 to it
#>
[cmdletbinding()]
param (

    [Parameter(Mandatory)]
    [String]$Path,


    [Parameter(Mandatory)]
    [string]$VersionNumber,


    [string]$ToolPath

)

function Update-DacpacVerion
{
    param(
        [parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [System.Version]$VersionNumber,

        [string]$ToolPath
    )
    
    #Specifying the Error Preference within the function scope to help catch errors
    $ErrorActionPreference = 'Stop'


    # Add SQL methods from Dlls, using Test-Path to determine which version to import based on VS version
    try
    {
        if (![string]::IsNullOrEmpty($ToolPath))
        {
            Write-Verbose 'No user provided ToolPath, so searching default locatons' -verbose

            if (Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll') 
            {
                Write-Verbose 'Found SQLServer DLLs for VS2015, attempting to import using Add-Type' -verbose
                Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll'
                Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.dll'
            }
            elseif (Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll' )
            {
                Write-Verbose 'Found SQLServer DLLs for VS2013, attempting to import using Add-Type' -verbose
                Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll'
                Add-Type -Path 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.dll'
            } else 
            {
                Write-error "Cannot find DLLs in expected default locations"
            }
        } else 
        {
            Write-Verbose "Looking for tools in user provided [$ToolPath]" -verbose
            if (Test-Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll") 
            {
                Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll"
                Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.dll"
            } else 
            {
                Write-error "Invalid tool path provided cannot load DLLs"
            }
        }
    }
    catch
    {
        Write-Error 'Failed to load DLL, check all SDKs and SSDT are installed correctly in the Visual Studio folders.'
        Exit -1
    }

    #Loads the DacPac ready for updating
    $StorageType = [Microsoft.SqlServer.Dac.DacSchemaModelStorageType]::File
    $AccessType = [System.IO.FileAccess]::ReadWrite
    $DacPacObject = [Microsoft.SqlServer.Dac.DacPackage]::Load($Path,$StorageType,$AccessType)

    #Sets up various load options for updating dacpac
    $LoadOptions = New-Object Microsoft.SqlServer.Dac.Model.ModelLoadOptions($null)
    $LoadOptions.LoadAsScriptBackedModel = $true
    $LoadOptions.ModelStorageType = $StorageType
    $TSQLModel = [Microsoft.SqlServer.Dac.Model.TSqlModel]::LoadFromDacpac($Path, $LoadOptions)

    #sets up details to update in dacpac
    $DacpacOptions = New-Object Microsoft.SqlServer.Dac.PackageMetadata($null)
    $DacpacOptions.Description = $DacPacObject.Description
    $DacpacOptions.Name = $DacPacObject.Name
    $DacpacOptions.Version = $VersionNumber

    Try
    {
        Write-Verbose "Attempting to update $($DacPacObject.Name) with version number $VersionNumber" -Verbose
        #Updates the DacPack with specified details
        [Microsoft.SqlServer.Dac.DacPackageExtensions]::UpdateModel($DacPacObject,$TSQLModel,$DacpacOptions)
        Write-Verbose "Succeeded in updating $($DacPacObject.Name) with version number $VersionNumber" -Verbose
    }
    catch
    {
        Write-Warning "Failed to update DacPac $($DacPacObject.Name), due to error:"
        Write-Warning "$($error[0])"
    }

}

$VersionNumber = ($VersionNumber -split '_' )[-1]

$DacPacFiles = Get-ChildItem -Path $Path -Filter *.dacpac -Recurse

Write-Verbose "Found $($DacPacFiles.Count) dacpacs. Beginning to apply updated version number." -Verbose

Foreach ($DacPac in $DacPacFiles)
{
    Update-DacpacVerion -Path $DacPac.FullName -VersionNumber $VersionNumber -ToolPath $ToolPath
}