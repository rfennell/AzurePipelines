@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Configuration.psm1'

# Version number of this module.
ModuleVersion = '1.5.0'

# ID used to uniquely identify this module
GUID = 'e56e5bec-4d97-4dfd-b138-abbaa14464a6'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# Copyright statement for this module
Copyright = 'Copyright (c) 2014-2021 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for storing and reading configuration values, with full PS Data serialization, automatic configuration for modules and scripts, etc.'

# Exports - populated by the build
FunctionsToExport = @('Export-Configuration','Get-ConfigurationPath','Import-Configuration','Import-ParameterConfiguration')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = 'Get-StoragePath'
RequiredModules = @('Metadata')

# List of all files packaged with this module
FileList = @('.\Configuration.psd1','.\Configuration.psm1')

PrivateData = @{
    # Allows overriding the default paths where Configuration stores it's configuration
    # Within those folders, the module assumes a "powershell" folder and creates per-module configuration folders
    PathOverride = @{
        # Where the user's personal configuration settings go.
        # Highest presedence, overrides all other settings.
        # Defaults to $Env:LocalAppData on Windows
        # Defaults to $Env:XDG_CONFIG_HOME elsewhere ($HOME/.config/)
        UserData       = ""
        # On some systems there are "roaming" user configuration stored in the user's profile. Overrides machine configuration
        # Defaults to $Env:AppData on Windows
        # Defaults to $Env:XDG_CONFIG_DIRS elsewhere (or $HOME/.local/share/)
        EnterpriseData = ""
        # Machine specific configuration. Overrides defaults, but is overriden by both user roaming and user local settings
        # Defaults to $Env:ProgramData on Windows
        # Defaults to /etc/xdg elsewhere
        MachineData    = ""
    }
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for the PoshCode and PowerShellGet modules
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # The semver pre-release version information
        PreRelease = ''

        # Keyword tags to help users find this module via navigations and search.
        Tags = @('Development','Configuration','Settings','Storage')

        # The web address of this module's project or support homepage.
        ProjectUri = "https://github.com/PoshCode/Configuration"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = "http://opensource.org/licenses/MIT"

        # Release notes for this particular version of the module
        ReleaseNotes = '
        - Extract the Metadata module
        - Add support for arbitrary AllowedVariables
        '
    }
}

}






