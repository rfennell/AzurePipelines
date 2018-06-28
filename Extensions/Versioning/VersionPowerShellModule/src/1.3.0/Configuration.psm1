# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters     = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

$ConfigurationRoot = Get-Variable PSScriptRoot* -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "PSScriptRoot" } | ForEach-Object { $_.Value }
if(!$ConfigurationRoot) {
    $ConfigurationRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

function InitializeStoragePaths {
    [CmdletBinding()]
    param(
        $EnterpriseData,
        $UserData,
        $MachineData
    )

    $PathOverrides = $MyInvocation.MyCommand.Module.PrivateData.PathOverride

    # Where the user's personal configuration settings go.
    # Highest presedence, overrides all other settings.
    if ([string]::IsNullOrWhiteSpace($UserData)) {
        if (!($UserData = $PathOverrides.UserData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
                if (!($UserData = $Env:XDG_CONFIG_HOME)) {
                    $UserData = Join-Path $HOME .config/
                }
            } else {
                # Defaults to $Env:LocalAppData on Windows
                if (!($UserData = $Env:LocalAppData)) {
                    $UserData = [Environment]::GetFolderPath("LocalApplicationData")
                }
            }
        }
    }

    # On some systems there are "roaming" user configuration stored in the user's profile. Overrides machine configuration
    if ([string]::IsNullOrWhiteSpace($EnterpriseData)) {
        if (!($EnterpriseData = $PathOverrides.EnterpriseData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
                if (!($EnterpriseData = @($Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0] )) {
                    $EnterpriseData = Join-Path $HOME .local/share/
                }
            } else {
                # Defaults to $Env:AppData on Windows
                if (!($EnterpriseData = $Env:AppData)) {
                    $EnterpriseData = [Environment]::GetFolderPath("ApplicationData")
                }
            }
        }
    }

    # Machine specific configuration. Overrides defaults, but is overriden by both user roaming and user local settings
    if ([string]::IsNullOrWhiteSpace($MachineData)) {
        if (!($MachineData = $PathOverrides.MachineData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to /etc/xdg elsewhere
                $XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator) | Where-Object { $_ -and (Test-Path $_) }
                if (!($MachineData = if ($XdgConfigDirs.Count -gt 1) {
                            $XdgConfigDirs[1]
                        })) {
                    $MachineData = "/etc/xdg/"
                }
            } else {
                # Defaults to $Env:ProgramData on Windows
                if (!($MachineData = $Env:ProgramAppData)) {
                    $MachineData = [Environment]::GetFolderPath("CommonApplicationData")
                }
            }
        }
    }

    Join-Path $EnterpriseData powershell
    Join-Path $UserData powershell
    Join-Path $MachineData powershell
}

$EnterpriseData, $UserData, $MachineData = InitializeStoragePaths $EnterpriseData $UserData $MachineData

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Force -Args @($Converters) -Verbose:$false

function ParameterBinder {
    if(!$Module) {
        [System.Management.Automation.PSModuleInfo]$Module = . {
            $Command = ($CallStack)[0].InvocationInfo.MyCommand
            $mi = if($Command.ScriptBlock -and $Command.ScriptBlock.Module) {
                $Command.ScriptBlock.Module
            } else {
                $Command.Module
            }

            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object { ($_.Name -eq $mi.Name) -and $_.ExportedCommands } | Select-Object -First 1) {
                   $mi = $mi2
                }
            }
            $mi
        }
    }

    if(!$CompanyName) {
        [String]$CompanyName = . {
            if($Module){
                $CName = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($CName -eq "Unknown" -or -not $CName) {
                    $CName = $Module.Author
                    if($CName -eq "Unknown" -or -not $CName) {
                        $CName = "AnonymousModules"
                    }
                }
                $CName
            } else {
                "AnonymousScripts"
            }
        }
    }

    if(!$Name) {
        [String]$Name = $(if($Module) { $Module.Name } <# else { ($CallStack)[0].InvocationInfo.MyCommand.Name } #>)
    }

    if(!$DefaultPath -and $Module) {
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 })
    }
}

function Get-ConfigurationPath {
    #.Synopsis
    #   Gets an storage path for configuration files and data
    #.Description
    #   Gets an AppData (or roaming profile) or ProgramData path for configuration and data storage. The folder returned is guaranteed to exist (which means calling this function actually creates folders).
    #
    #   Get-ConfigurationPath is designed to be called from inside a module function WITHOUT any parameters.
    #
    #   If you need to call Get-ConfigurationPath from outside a module, you should pipe the ModuleInfo to it, like:
    #   Get-Module Powerline | Get-ConfigurationPath
    #
    #   As a general rule, there are three scopes which result in three different root folders
    #       User:       $Env:LocalAppData
    #       Machine:    $Env:ProgramData
    #       Enterprise: $Env:AppData (which is the "roaming" folder of AppData)
    #
    #.NOTES
    #   1.  This command is primarily meant to be used in modules, to find a place where they can serialize data for storage.
    #   2.  It's techincally possible for more than one module to exist with the same name.
    #       The command uses the Author or Company as a distinguishing name.
    #
    #.Example
    #   $CacheFile = Join-Path (Get-ConfigurationPath) Data.clixml
    #   $Data | Export-CliXML -Path $CacheFile
    #
    #   This example shows how to use Get-ConfigurationPath with Export-CliXML to cache data as clixml from inside a module.
    [Alias("Get-StoragePath")]
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo')]
    param(
        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [ValidateSet("User", "Machine", "Enterprise")]
        [string]$Scope = "Enterprise",

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version,

        # By default, Get-ConfigurationPath creates the folder if it doesn't already exist
        # This switch allows overriding that behavior: if set, does not create missing paths
        [Switch]$SkipCreatingFolder
    )
    begin {
        $PathRoot = $(switch ($Scope) {
            "Enterprise" { $EnterpriseData }
            "User"       { $UserData }
            "Machine"    { $MachineData }
            # This should be "Process" scope, but what does that mean?
            # "AppDomain"  { $MachineData }
            default { $EnterpriseData }
        })
        if(Test-Path $PathRoot) {
            $PathRoot = Resolve-Path $PathRoot
        } elseif(!$SkipCreatingFolder) {
            Write-Warning "The $Scope path $PathRoot cannot be found"
        }
    }

    process {
        . ParameterBinder

        if(!$Name) {
            Write-Error "Empty Name ($Name) in $($PSCmdlet.ParameterSetName): $($PSBoundParameters | Format-List | Out-String)"
            throw "Could not determine the storage name, Get-ConfigurationPath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
        if($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        if(Test-Path $PathRoot -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at $PathRoot"
        }

        if(!$SkipCreatingFolder -and !(Test-Path $PathRoot -PathType Container)) {
            $null = New-Item $PathRoot -Type Directory -Force
        }

        # Note: this used to call Resolve-Path
        $PathRoot
    }
}

function Export-Configuration {
    <#
        .Synopsis
            Exports a configuration object to a specified path.
        .Description
            Exports the configuration object to a file, by default, in the Roaming AppData location

            NOTE: this exports the FULL configuration to this file, which will override both defaults and local machine configuration when Import-Configuration is used.
        .Example
            @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now } | Export-Configuration

            This example shows how to use Export-Configuration in your module to cache some data.

        .Example
            Get-Module Configuration | Export-Configuration @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now }

            This example shows how to use Export-Configuration to export data for use in a specific module.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(DefaultParameterSetName='__ModuleInfo',SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,


        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Parameter(ParameterSetName = "ManualOverride")]
        [ValidateSet("User", "Machine", "Enterprise")]
        [string]$Scope = "Enterprise",

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    process {
        . ParameterBinder
        if(!$Name) {
            throw "Could not determine the storage name, Export-Configuration should only be called from inside a script or module, or by piping ModuleInfo to it."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath -AsHashtable:$AsHashtable
    }
}

function Import-Configuration {
    #.Synopsis
    #   Import the full, layered configuration for the module.
    #.Description
    #   Imports the DefaultPath Configuration file, and then imports the Machine, Roaming (enterprise), and local config files, if they exist.
    #   Each configuration file is layered on top of the one before (so only needs to set values which are different)
    #.Example
    #   $Configuration = Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load the cached data
    #
    #.Example
    #   $Configuration = Get-Module Configuration | Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load data cached for another module
    #
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered
    )
    begin {
        # Write-Debug "Import-Configuration for module $Name"
    }
    process {
        . ParameterBinder

        if(!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }

        if($DefaultPath -and (Test-Path $DefaultPath -Type Container)) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        $Configuration = if($DefaultPath -and (Test-Path $DefaultPath)) {
                             Import-Metadata $DefaultPath -ErrorAction Ignore -Ordered:$Ordered
                         } else { @{} }
        # Write-Debug "Module Configuration: ($DefaultPath)`n$($Configuration | Out-String)"


        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope Machine -SkipCreatingFolder
        $MachinePath = Join-Path $MachinePath Configuration.psd1
        $Machine = if(Test-Path $MachinePath) {
                    Import-Metadata $MachinePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "Machine Configuration: ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-ConfigurationPath @Parameters -Scope Enterprise -SkipCreatingFolder
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if(Test-Path $EnterprisePath) {
                    Import-Metadata $EnterprisePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "Enterprise Configuration: ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-ConfigurationPath @Parameters -Scope User -SkipCreatingFolder
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if(Test-Path $LocalUserPath) {
                    Import-Metadata $LocalUserPath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "LocalUser Configuration: ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
                         Update-Object $Enterprise |
                         Update-Object $LocalUser
    }
}

# SIG # Begin signature block
# MIIXzgYJKoZIhvcNAQcCoIIXvzCCF7sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUMvAGf0/J+cqbtsOdqCrlu3E
# uL+gghMBMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggUwMIIEGKADAgEC
# AhAFmB+6PJIk/oqP7b4FPfHsMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMTcwNjE0MDAwMDAwWhcNMTgwNjAxMTIwMDAwWjBtMQswCQYDVQQG
# EwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3QgSGVucmlldHRh
# MRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pvZWwgSC4gQmVu
# bmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANALmLHevB7LvTmI
# p2oVErnz915fP1JUKoC+/5BRWUtAGooxg95jxX8+qT1yc02ZnkK7u1UyM0Mfs3b8
# MzhSqe5OkkQeT2RHrGe52+0/0ZWD68pvUBZoMQxrAnWJETjFO6IoXPKmoXN3zzpF
# +5s/UIbNGI5mdiN4v4F93Yaajzu2ymsJsXK6NgRh/AUbUzUlefpOas+o06wT0vqp
# LniGWw26321zJo//2QEo5PBrJvDDDIBBN6Xn5A2ww6v6fH2KGk2qf4vpr58rhDIH
# fLOHLg9s35effaktygUMQBCFmxOAbPLKWId8n5+O7zbMfKw3qxqCp2QeXhjkIh9v
# ETIX9pECAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZl
# dQ5YMB0GA1UdDgQWBBQ8xh3xoTXbMfJUSyFBfPsrxoD8XzAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGG
# L2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MEwGA1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcw
# AoZCaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3Vy
# ZWRJRENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
# BQADggEBAGvlfIiin9JAyL16oeCNApnAWLfZpUBob4D+XLzdRJXidPq/pvNkE9Rg
# pRZFaWs30f2WPhWeqCpSCahoHzFsD5S9mOzsGTXsT+EdjAS0yEe1t9LfMvEC/pI3
# aBQJeJ/DdgpTMUEUJSvddc0P0NbDJ6TJC/niEMOJ8XvsfF75J4YVJ10yVNahbAuU
# MrRrRLe30pW74MRv1s7SKxwPmLhcsMQuK0mWGERtGYMwDHwW0ZdRHKNDGHRsl0Wh
# DS1P8+JRpE3eNFPcO17yiOfKDnVh+/1AOg7QopD6R6+P9rErorebsvW680s4WTlr
# hDcMsTOX0js2KFF6uT4nSojS4GNlSxExggQ3MIIEMwIBATCBhjByMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBT
# aWduaW5nIENBAhAFmB+6PJIk/oqP7b4FPfHsMAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQWgh/z
# o9fxOAU7KZsen+mCNQZrAjANBgkqhkiG9w0BAQEFAASCAQDE7RTUFVkhTW+3Sa9Q
# jx5vlzvBXKXoURp+m9Dudb5WHkf8IPgml3wiNa/eKRcZsfLVF6hJX299JnCT96jv
# RwmPUgbrs9Rze5GXzAQ8JSd+BMMo2RiYIJkvqljDH5gao2EpAnQTARq4O4Zhu48q
# VBzHJIMEY70behdV+4+Fm6Q1dB/3+dlHpu5iyRwhHSpfRrHf/ZWzOsWdv5dbjUg3
# M35RVpd0Cmg+WXsgIeZaSkT2Bxkj2p5MMQIUVoha4r/Cmnb/bX5raUELKv5D1Aj2
# hYTfbvWFfILLBfJJRHi9mcVeeTGfS5DFBjv3H+p4JtvzsPoKvVc8DPlbZuVuthZ9
# mAx9oYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE4MDUwMTE0MzM0NVowIwYJKoZIhvcNAQkEMRYEFI37FzLL
# b9pA9VpgI9mICB0R1t9tMA0GCSqGSIb3DQEBAQUABIIBADU9/Jlrjgd+zioSzOgM
# j8cLU9duZ8/0HuVO6QUzNLQ2KlyRqcr2CfXE6dGIwMHZ05q/WLOMXTVdon6UA5Wx
# HnJGcX5pLW0xobMSEuS8XqLzZ4EOGy+Y+AFSBhgdS50hjZpTijQtpu2YDbxuSwHn
# fC9xBxmdk8bOJO9ujm4SrYI/jHgXbl8qPMGKRlVk6CaJmZ1u2q5QsFfTmnyyylZP
# y0kjDN6ATA6xvTVmSm0/rzYXDogvxM242PTsBVEQAQ7SrLl9w7gXF8+3h2IeL5cF
# zq22gu051P8ls+FXj/QaqqlvGa30XBAF/f69oCcYScFAXSgWWZ2H18p1zRZGU3xP
# j/A=
# SIG # End signature block
