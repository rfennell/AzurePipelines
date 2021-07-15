#Region '.\Header\param.ps1' 0
# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

Import-Module Metadata -Force -Args @($Converters) -Verbose:$false -Global
#EndRegion '.\Header\param.ps1' 10
#Region '.\Private\InitializeStoragePaths.ps1' 0
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

$EnterpriseData, $UserData, $MachineData = InitializeStoragePaths -EnterpriseData $EnterpriseData -UserData $UserData -MachineData $MachineData
#EndRegion '.\Private\InitializeStoragePaths.ps1' 72
#Region '.\Private\ParameterBinder.ps1' 0
function ParameterBinder {
    if (!$Module) {
        [System.Management.Automation.PSModuleInfo]$Module = . {
            $Command = ($CallStack)[0].InvocationInfo.MyCommand
            $mi = if ($Command.ScriptBlock -and $Command.ScriptBlock.Module) {
                $Command.ScriptBlock.Module
            } else {
                $Command.Module
            }

            if ($mi -and $mi.ExportedCommands.Count -eq 0) {
                if ($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object { ($_.Name -eq $mi.Name) -and $_.ExportedCommands } | Select-Object -First 1) {
                    $mi = $mi2
                }
            }
            $mi
        }
    }

    if (!$CompanyName) {
        [String]$CompanyName = . {
            if ($Module) {
                $CName = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]", "_"
                if ($CName -eq "Unknown" -or -not $CName) {
                    $CName = $Module.Author
                    if ($CName -eq "Unknown" -or -not $CName) {
                        $CName = "AnonymousModules"
                    }
                }
                $CName
            } else {
                "AnonymousScripts"
            }
        }
    }

    if (!$Name) {
        [String]$Name = $(if ($Module) {
                $Module.Name
            } <# else { ($CallStack)[0].InvocationInfo.MyCommand.Name } #>)
    }

    if (!$DefaultPath -and $Module) {
        [String]$DefaultPath = $(if ($Module) {
                Join-Path $Module.ModuleBase Configuration.psd1
            })
    }
}
#EndRegion '.\Private\ParameterBinder.ps1' 49
#Region '.\Public\Export-Configuration.ps1' 0
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
    # PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Callstack', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Module', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DefaultPath', Justification = 'This is referenced in ParameterBinder')]
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo', SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,


        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Name,

        # DefaultPath is IGNORED.
        # The parameter was here to match Import-Configuration, but it is meaningless in Export-Configuration
        # The only reason I haven't removed it is that I don't want to break any code that might be using it.
        # TODO: If we release a breaking changes Configuration 2.0, remove this parameter
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName = $true)]
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
        if (!$Name) {
            throw "Could not determine the storage name, Export-Configuration should only be called from inside a script or module, or by piping ModuleInfo to it."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name        = $Name
        }
        if ($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath -AsHashtable:$AsHashtable
    }
}
#EndRegion '.\Public\Export-Configuration.ps1' 93
#Region '.\Public\Get-ConfigurationPath.ps1' 0
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
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Callstack', Justification = 'This is referenced in ParameterBinder')]
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Module', Justification = 'This is referenced in ParameterBinder')]
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
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
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
                "Enterprise" {
                    $EnterpriseData
                }
                "User" {
                    $UserData
                }
                "Machine" {
                    $MachineData
                }
                # This should be "Process" scope, but what does that mean?
                # "AppDomain"  { $MachineData }
                default {
                    $EnterpriseData
                }
            })
        if (Test-Path $PathRoot) {
            $PathRoot = Resolve-Path $PathRoot
        } elseif (!$SkipCreatingFolder) {
            Write-Warning "The $Scope path $PathRoot cannot be found"
        }
    }

    process {
        . ParameterBinder

        if (!$Name) {
            Write-Error "Empty Name ($Name) in $($PSCmdlet.ParameterSetName): $($PSBoundParameters | Format-List | Out-String)"
            throw "Could not determine the storage name, Get-ConfigurationPath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]", "_"
        if ($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if ($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        if (Test-Path $PathRoot -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at $PathRoot"
        }

        if (!$SkipCreatingFolder -and !(Test-Path $PathRoot -PathType Container)) {
            $null = New-Item $PathRoot -Type Directory -Force
        }

        # Note: this used to call Resolve-Path
        $PathRoot
    }
}
#EndRegion '.\Public\Get-ConfigurationPath.ps1' 117
#Region '.\Public\Import-Configuration.ps1' 0
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Callstack', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Module', Justification = 'This is referenced in ParameterBinder')]
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DefaultPath', Justification = 'This is referenced in ParameterBinder')]
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName = $true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in configuration
        # BEWARE: This exposes the value of these variables in the calling context to the configuration file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables
    )
    begin {
        # Write-Debug "Import-Configuration for module $Name"
    }
    process {
        . ParameterBinder

        if (!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }

        $MetadataOptions = @{
            AllowedVariables = $AllowedVariables
            PSVariable       = $PSCmdlet.SessionState.PSVariable
            Ordered          = $Ordered
            ErrorAction      = "Ignore"
        }

        if ($DefaultPath -and (Test-Path $DefaultPath -Type Container)) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        $Configuration = if ($DefaultPath -and (Test-Path $DefaultPath)) {
            Import-Metadata $DefaultPath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Module Configuration: ($DefaultPath)`n$($Configuration | Out-String)"


        $Parameters = @{
            CompanyName = $CompanyName
            Name        = $Name
        }
        if ($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope Machine -SkipCreatingFolder
        $MachinePath = Join-Path $MachinePath Configuration.psd1
        $Machine = if (Test-Path $MachinePath) {
            Import-Metadata $MachinePath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Machine Configuration: ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-ConfigurationPath @Parameters -Scope Enterprise -SkipCreatingFolder
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if (Test-Path $EnterprisePath) {
            Import-Metadata $EnterprisePath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Enterprise Configuration: ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-ConfigurationPath @Parameters -Scope User -SkipCreatingFolder
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if (Test-Path $LocalUserPath) {
            Import-Metadata $LocalUserPath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "LocalUser Configuration: ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
            Update-Object $Enterprise |
            Update-Object $LocalUser
    }
}
#EndRegion '.\Public\Import-Configuration.ps1' 130
#Region '.\Public\Import-ParameterConfiguration.ps1' 0
function Import-ParameterConfiguration {
    <#
        .SYNOPSIS
            Loads a metadata file based on the calling command name and combines the values there with the parameter values of the calling function.
        .DESCRIPTION
            This function gives command authors and users an easy way to let the default parameter values of the command be set by a configuration file in the folder you call it from.

            Normally, you have three places to get parameter values from. In priority order, they are:
            - Parameters passed by the caller always win
            - The PowerShell $PSDefaultParameterValues hashtable appears to the function as if the user passed it
            - Default parameter values (defined in the function)

            If you call this command at the top of a function, it overrides (only) the default parameter values with

            - Values from a manifest file in the present working directory ($pwd)
        .EXAMPLE
            Given that you've written a script like:

            function New-User {
                [CmdletBinding()]
                param(
                    $FirstName,
                    $LastName,
                    $UserName,
                    $Domain,
                    $EMail,
                    $Department,
                    [hashtable]$Permissions
                )
                Import-ParameterConfiguration -Recurse
                # Possibly calculated based on (default) parameter values
                if (-not $UserName) { $UserName = "$FirstName.$LastName" }
                if (-not $EMail)    { $EMail = "$UserName@$Domain" }

                # Lots of work to create the user's AD account, email, set permissions etc.

                # Output an object:
                [PSCustomObject]@{
                    PSTypeName  = "MagicUser"
                    FirstName   = $FirstName
                    LastName    = $LastName
                    EMail       = $EMail
                    Department  = $Department
                    Permissions = $Permissions
                }
            }

            You could create a User.psd1 in a folder with just:

            @{ Domain = "HuddledMasses.org" }

            Now the following command would resolve the `User.psd1`
            And the user would get an appropriate email address automatically:

            PS> New-User Joel Bennett

            FirstName   : Joel
            LastName    : Bennett
            EMail       : Joel.Bennett@HuddledMasses.org

        .EXAMPLE
            Import-ParameterConfiguration works recursively (up through parent folders)

            That means it reads config files in the same way git reads .gitignore,
            with settings in the higher level files (up to the root?) being
            overridden by those in lower level files down to the WorkingDirectory

            Following the previous example to a ridiculous conclusion,
            we could automate creating users by creating a tree like:

            C:\HuddledMasses\Security\Admins\ with a User.psd1 in each folder:

            # C:\HuddledMasses\User.psd1:
            @{
                Domain = "HuddledMasses.org"
            }

            # C:\HuddledMasses\Security\User.psd1:
            @{
                Department = "Security"
                Permissions = @{
                    Access = "User"
                }
            }

            # C:\HuddledMasses\Security\Admins\User.psd1
            @{
                Permissions = @{
                    Access = "Administrator"
                }
            }

            And then switch to the Admins directory and run:

            PS> New-User Joel Bennett

            FirstName   : Joel
            LastName    : Bennett
            EMail       : Joel.Bennett@HuddledMasses.org
            Department  : Security
            Permissions : { Access = Administrator }

        .EXAMPLE
            Following up on our earlier example, let's look at a way to use imagine that -FileName parameter.
            If you wanted to use a different configuration files than your Noun, you can pass the file name in.

            You could even use one of your parameters to generate the file name. If we modify the function like ...

            function New-User {
                [CmdletBinding()]
                param(
                    $FirstName,
                    $LastName,
                    $UserName,
                    $Domain,
                    $EMail,
                    $Department,
                    [hashtable]$Permissions
                )
                Import-ParameterConfiguration -FileName "${Department}User.psd1"
                # Possibly calculated based on (default) parameter values
                if (-not $UserName) { $UserName = "$FirstName.$LastName" }
                if (-not $EMail)    { $EMail = "$UserName@$Domain" }

                # Lots of work to create the user's AD account and email etc.
                [PSCustomObject]@{
                    PSTypeName = "MagicUser"
                    FirstName = $FirstName
                    LastName = $LastName
                    EMail      = $EMail
                    # Passthru for testing
                    Permissions = $Permissions
                }
            }

            Now you could create a `SecurityUser.psd1`

            @{
                Domain = "HuddledMasses.org"
                Permissions = @{
                    Access = "Administrator"
                }
            }

            And run:

            PS> New-User Joel Bennett -Department Security
    #>
    [CmdletBinding()]
    param(
        # The folder the configuration should be read from. Defaults to the current working directory
        [string]$WorkingDirectory = $pwd,
        # The name of the configuration file.
        # The default value is your command's Noun, with the ".psd1" extention.
        # So if you call this from a command named Build-Module, the noun is "Module" and the config $FileName is "Module.psd1"
        [string]$FileName,

        # If set, considers configuration files in the parent, and it's parent recursively
        [switch]$Recurse,

        # Allows extending the valid variables which are allowed to be referenced in configuration
        # BEWARE: This exposes the value of these variables in the calling context to the configuration file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables
    )

    $CallersInvocation = $PSCmdlet.SessionState.PSVariable.GetValue("MyInvocation")
    $BoundParameters = @{} + $CallersInvocation.BoundParameters
    $AllParameters = $CallersInvocation.MyCommand.Parameters.Keys
    if (-not $PSBoundParameters.ContainsKey("FileName")) {
        $FileName = "$($CallersInvocation.MyCommand.Noun).psd1"
    }

    $MetadataOptions = @{
        AllowedVariables = $AllowedVariables
        PSVariable       = $PSCmdlet.SessionState.PSVariable
        ErrorAction      = "SilentlyContinue"
    }

    do {
        $FilePath = Join-Path $WorkingDirectory $FileName

        Write-Debug "Initializing parameters for $($CallersInvocation.InvocationName) from $(Join-Path $WorkingDirectory $FileName)"
        if (Test-Path $FilePath) {
            $ConfiguredDefaults = Import-Metadata $FilePath @MetadataOptions

            foreach ($Parameter in $AllParameters) {
                # If it's in the defaults AND it was not already set at a higher precedence
                if ($ConfiguredDefaults.ContainsKey($Parameter) -and -not ($BoundParameters.ContainsKey($Parameter))) {
                    Write-Debug "Export $Parameter = $($ConfiguredDefaults[$Parameter])"
                    $BoundParameters.Add($Parameter, $ConfiguredDefaults[$Parameter])
                    # This "SessionState" is the _callers_ SessionState, not ours
                    $PSCmdlet.SessionState.PSVariable.Set($Parameter, $ConfiguredDefaults[$Parameter])
                }
            }
        }
        Write-Debug "Recurse:$Recurse -and $($BoundParameters.Count) of $($AllParameters.Count) Parameters and $WorkingDirectory"
    } while ($Recurse -and ($AllParameters.Count -gt $BoundParameters.Count) -and ($WorkingDirectory = Split-Path $WorkingDirectory))
}
#EndRegion '.\Public\Import-ParameterConfiguration.ps1' 200
