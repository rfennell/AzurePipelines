@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Metadata.psm1'

# Version number of this module.
ModuleVersion = '1.5.0'

# ID used to uniquely identify this module
GUID = 'c7505d40-646d-46b5-a440-8a81791c5d23'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# Copyright statement for this module
Copyright = 'Copyright (c) 2014-2021 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for PowerShell data serialization'

# This doesn't make it into the build output, so it's irrelevant
FunctionsToExport = @('Add-MetadataConverter','ConvertFrom-Metadata','ConvertTo-Metadata','Export-Metadata','Get-Metadata','Import-Metadata','Test-PSVersion','Update-Metadata','Update-Object')
CmdletsToExport   = @()
VariablesToExport = @()
AliasesToExport = @('Get-ManifestValue','Update-Manifest')
PrivateData   = @{
    PSData = @{
        # The semver pre-release version information
        PreRelease   = ''

        # Keyword tags to help users find this module via navigations and search.
        Tags         = @('Serialization', 'Metadata', 'Development', 'Configuration', 'Settings')

        # The web address of this module's project or support homepage.
        ProjectUri   = "https://github.com/PoshCode/Metadata"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri   = "http://opensource.org/licenses/MIT"

        # Release notes for this particular version of the module
        ReleaseNotes = '
        - Extracted Metadata from Configuration for the first time
        '
    }
}

}




