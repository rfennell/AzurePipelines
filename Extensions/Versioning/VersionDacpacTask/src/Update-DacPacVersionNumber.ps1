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
)

function Get-Toolpath {
    param(
        $ToolPath,
        $VSVersionFilter = "",
        $SDKVersion = ""
    )

    if ([string]::IsNullOrEmpty($ToolPath.Trim())) {
        Write-Host 'No user provided ToolPath, so searching default locations' -verbose

        # Modern File Locations
        $basePaths = "C:\Program Files\Microsoft Visual Studio", "C:\Program Files (x86)\Microsoft Visual Studio"
        if ([string]::IsNullOrEmpty($VSVersionFilter.Trim())) {
            $VSVersions = "2022", "2019", "2017"
        }
        else {
            $VSVersions = $VSVersionFilter
        }

        Write-Host "Scan standard Visual Studio locations (2017 and later)"
        foreach ($basePath in $basePaths) {
            foreach ($version in $VSVersions) {
                # we don't know the SKU name so we loop
                # Write-Verbose "Checking in '$basePath\$version'"

                if (Test-Path("$basePath\$version")) {
                    Write-Verbose "Found a VS$version SKU in '$basePath\$version'"
                    $paths = Get-ChildItem -path "$basePath\$version" -Filter "Microsoft.SqlServer.Dac.Extensions.dll" -Recurse -ErrorAction SilentlyContinue | % { $_.FullName } | sort-object -Descending
                    Write-Verbose "Found $($paths.Count) SDK(s)"
                    foreach ($path in $paths) {
                        Write-Verbose "Considering '$path'"
                        if ([string]::IsNullOrEmpty($SDKVersion.Trim())) {
                            Write-host "Found the newest SDK in '$(Split-Path -Path $path)'"
                            return Split-Path -Path $path
                        }
                        else {
                            if ($path.contains($SDKVersion)) {
                                Write-host "Found a matching SDK version 'SDKVersion' in '$(Split-Path -Path $path)'"
                                return Split-Path -Path $path
                            }
                        }
                    }
                }
                else {
                    Write-Verbose "VS$version is not installled in '$basePath\$version'"
                }
            }
        }

        # for older versions we check each
        $basePaths = "C:\Program Files (x86)\Microsoft Visual Studio 14.0", "C:\Program Files (x86)\Microsoft Visual Studio 12.0", "C:\Program Files\Microsoft SQL Server"

        Write-Host "Scan legacy locations"
        foreach ($basePath in $basePaths) {
            # we don't know the SKU name so we loop
            #Write-Verbose "Checking in '$basePath'" -Verbose

            if (Test-Path("$basePath")) {
                $paths = Get-ChildItem -path "$basePath" -Filter "Microsoft.SqlServer.Dac.Extensions.dll" -Recurse -ErrorAction SilentlyContinue | % { $_.FullName } | sort-object -Descending
                Write-Verbose "Found $($paths.Count) SDK(s)"
                foreach ($path in $paths) {
                    Write-Verbose "Considering '$path'"
                    if ([string]::IsNullOrEmpty($SDKVersion.Trim())) {
                        Write-host "Found the newest SDK in '$(Split-Path -Path $path)'"
                        return Split-Path -Path $path
                    }
                    else {
                        if ($path.contains($SDKVersion)) {
                            Write-host "Found a matching SDK version 'SDKVersion' in '$(Split-Path -Path $path)'"
                            return Split-Path -Path $path
                        }
                    }
                }
            }
            else {
                Write-Verbose "'$basePath' is not installed"
            }
        }

        Write-error 'Cannot find assemblies in any standard locations' -verbose
    }
    else {
        Write-Verbose "Looking for tools in user provided [$ToolPath]" -verbose
        if (Test-Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll") {
            Write-Verbose 'Found assemblies in user provided location' -verbose
        }
        else {
            Write-error 'Cannot find assemblies in user provided location' -verbose
        }
    }

    $ToolPath

}

function Update-DacpacVerion {
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
    try {
        Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.Extensions.dll"
        Add-Type -Path "$ToolPath\Microsoft.SqlServer.Dac.dll"
    }
    catch {
        Write-Error 'Failed to load DLL, check all SDKs and SSDT are installed correctly in the Visual Studio folders.'
        Exit -1
    }

    #Loads the DacPac ready for updating
    $StorageType = [Microsoft.SqlServer.Dac.DacSchemaModelStorageType]::File
    $AccessType = [System.IO.FileAccess]::ReadWrite
    $DacPacObject = [Microsoft.SqlServer.Dac.DacPackage]::Load($Path, $StorageType, $AccessType)

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

    Try {
        Write-Verbose "Attempting to update $($DacPacObject.Name) with version number $VersionNumber" -Verbose
        #Updates the DacPack with specified details
        [Microsoft.SqlServer.Dac.DacPackageExtensions]::UpdateModel($DacPacObject, $TSQLModel, $DacpacOptions)
        Write-Verbose "Succeeded in updating $($DacPacObject.Name) with version number $VersionNumber" -Verbose
    }
    catch {
        Write-Warning "Failed to update DacPac $($DacPacObject.Name), due to error:"
        Write-Warning "$($error[0])"
    }
}

function Update-SqlProjVersion {
    param (
        [string]$Path,

        [version]$VersionNumber,

        [string]$RegexPattern
    )

    $SqlProj = Get-Content -Path $Path -Raw

    if ($SqlProj -match '<DacVersion>') {
        $SqlProj = $SqlProj -Replace "<DacVersion>$RegexPattern<\/DacVersion>", "<DacVersion>$VersionNumber</DacVersion>"
    }
    else {
        $SqlProj = $SqlProj -replace "<Name>", "<DacVersion>$VersionNumber</DacVersion><Name>"
    }

    Set-Content -Path $Path -Value $SqlProj -Encoding UTF8
}

$Path = Get-VstsInput -Name "Path"
$VersionNumber = Get-VstsInput -Name "VersionNumber"
$ToolPath = Get-VstsInput -Name "ToolPath"
$InjectVersion = Get-VstsInput -Name "InjectVersion"
$VersionRegex = Get-VstsInput -Name "VersionRegex"
$outputversion = Get-VstsInput -Name "outputversion"
$VSVersion = Get-VstsInput -Name "VSVersion"
$SDKVersion = Get-VstsInput -Name "SDKVersion"


# check if we are in test mode i.e.
If ($VersionNumber -eq "" -and $path -eq "") { Exit }

# Get and validate the version data
if ([System.Convert]::ToBoolean($InjectVersion) -eq $true) {
    Write-Verbose "Using the version number directly"
    $NewVersion = $VersionNumber
}
else {
    Write-Verbose "Extracting version number from build number"

    $VersionData = [regex]::matches($VersionNumber, $VersionRegex)
    switch ($VersionData.Count) {
        0 {
            Write-Error "Could not find version number data in $VersionNumber."
            exit 1
        }
        1 {}
        default {
            Write-Warning "Found more than instance of version data in $VersionNumber."
            Write-Warning "Will assume first instance is version."
        }
    }
    $NewVersion = $VersionData[0]
}
Write-Verbose "Version: $NewVersion"


$ToolPath = Get-Toolpath -ToolPath $ToolPath -VSVersion $VSVersion -SDKVersion $SDKVersion


$DacPacFiles = Get-ChildItem -Path $Path -Include *.dacpac -Exclude master.dacpac, msdb.dacpac -Recurse

if ($DacPacFiles.Count -gt 0) {
    Write-Verbose "Found $($DacPacFiles.Count) dacpacs. Beginning to apply updated version number $NewVersion." -Verbose

    Foreach ($DacPac in $DacPacFiles) {
        Update-DacpacVerion -Path $DacPac.FullName -VersionNumber ([System.Version]::Parse($NewVersion)) -ToolPath $ToolPath
    }
}
else {
    Write-Verbose "Found no dacpacs, checking for sqlproj files to version instead" -Verbose
    $SqlProjFiles = Get-ChildItem -Path $Path -Include *.sqlproj -Recurse

    if ($SqlProjFiles) {
        Write-Verbose "Found $($SqlProjFiles.Count) sqlproj files. Adding or updating DacVersion field." -Verbose

        foreach ($SqlProj in $SqlProjFiles) {
            Write-Verbose "Updating $($SqlProj.Basename) SQL Proj file."
            Update-SqlProjVersion -Path $SqlProj.Fullname -VersionNumber ([System.Version]::Parse($NewVersion)) -RegexPattern $VersionRegex
        }
    }
}
Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
