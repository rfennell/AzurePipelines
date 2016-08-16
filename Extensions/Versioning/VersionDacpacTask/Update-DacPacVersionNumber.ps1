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

    [String]$Path,
    [string]$VersionNumber,

    [string]$ToolPath,

    $VersionRegex

)


function Get-Toolpath
{
    param(
        $ToolPath
    )

    if ([string]::IsNullOrEmpty($ToolPath.Trim()))
    {
        Write-Verbose 'No user provided ToolPath, so searching default locatons' -verbose
        $ToolPath = 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120'
        if (Test-Path ("$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll"))
        {
           Write-Verbose 'Found SQL2014 assemblies' -verbose
        } else
        {
            Write-Verbose 'Cound not find SQL2014 assemblies' -verbose
            $ToolPath = 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120'
            if (Test-Path ("$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll"))
            {
                 Write-Verbose 'Found SQL2012 assemblies' -verbose 
            }
            else
            {
                 Write-error "Cannot find DLLs in expected SQL 2012 or 2014 default locations" 
            }
        }  
    } else
    {
        Write-Verbose "Looking for tools in user provided [$ToolPath]" -verbose
        if (Test-Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll") 
        {
             Write-Verbose 'Found assemblies in user provide location' -verbose 
        }
        else
        {
             Write-error 'Cannont find assemblies in user provide location' -verbose 
        }
    }

    $ToolPath

}

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

    $ToolPath = Get-Toolpath -ToolPath $ToolPath

    # Add SQL methods from Dlls, using Test-Path to determine which version to import based on VS version
    try
    {
        Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll"
        Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.dll"
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

# check if we are in test mode i.e. 
If ($VersionNumber -eq "" -and $path -eq "") {Exit}

# Get and validate the version data
$VersionData = [regex]::matches($VersionNumber,$VersionRegex)
switch($VersionData.Count)
{
0        
    { 
        Write-Error "Could not find version number data in $VersionNumber."
        exit 1
    }
1 {}
default 
    { 
        Write-Warning "Found more than instance of version data in $VersionNumber." 
        Write-Warning "Will assume first instance is version."
    }
}
$NewVersion = $VersionData[0]
Write-Verbose "Version: $NewVersion"


$DacPacFiles = Get-ChildItem -Path $Path -Filter *.dacpac -Recurse

Write-Verbose "Found $($DacPacFiles.Count) dacpacs. Beginning to apply updated version number $NewVersion." -Verbose

Foreach ($DacPac in $DacPacFiles)
{
    Update-DacpacVerion -Path $DacPac.FullName -VersionNumber ([System.Version]::Parse($NewVersion)) -ToolPath $ToolPath
}