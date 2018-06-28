# Configuration

A module for saving and loading settings and configuration objects for PowerShell modules (and scripts).

The Configuration module supports layered configurations with default values, and serializes objects and hashtables to the simple PowerShell metadata format with the ability to extend how your custom types are serialized, so your configuration files are just .psd1 files!

The key feature is that you don't have to worry about where to store files, and modules using the Configuration commands will be able to easily store data even when installed in write-protected folders like Program Files.

Supports WindowsPowerShell, as well as PowerShell Core on Windows, Linux and OS X.

## Installation

```posh
Install-Module Configuration
```

## Usage

The Configuration module is designed to be used by other modules (or from scripts) to allow the storage of configuration data (generally, hashtables, but any PSObject).

In its simplest form, you add a `Configuration.psd1` file to a module you're authoring, and put your default settings in it -- perhaps something as simple as this:

```posh
@{
    DriveName = "data"
}
```

Then, in your module, you import those settings _in a function_ when you need them, or expose them to your users like this:

```posh
function Get-FaqConfig {
    Import-Configuration
}
```

Perhaps, in a simple case like this one, you might write a wrapper function so your users can get _and set_ that one configuration option directly:

```posh
function Get-DataDriveName {
    $script:Config = Import-Configuration
    $config.DriveName
}

function Set-DataDriveName {
    param([Parameter(Mandatory)][String]$Name)

    @{ DriveName = $Name} | Export-Config
}
```

Of course, you could have imported the configuration, edited that one setting, and then exported the whole config, but you can also just export a few settings, because `Import-Configuration` supports a layered configuration. More on that in a moment, but first, let's talk about how this all works.

### Versioning

Versioning your configuration is supported, but is only done explicitly (in `Import-Configuration`, `Export-Configuration`, and `Get-ConfigurationPath`). Whenever you need to change your module's configuration in an incompatible way, you can write a migration function that runs at import-time in your new version, something like this:

```posh
# Specify a script-level version number
$ConfigVersion = @{ Version = 1.1 }

function MigrateData {
    # Specify the version you want to migrate
    $OldVersion = @{ <# I didn't specify a version at first #> }

    # If there are no configuration files, migrate them
    if(!(Get-ConfigurationPath @ConfigVersion | Get-ChildItem -File)) {
        # Import the old config
        $oldConfig = Import-Configuration @OldVersion
        # Transform your configuration however you like
        $newConfig = @{ PSDriveName = $existing.DriveName }
        # Export the new config
        $newConfig | Export-Configuration @ConfigVersion
    }
}

# Call your migration function during module import
MigrateData
```

Then you just need to be sure you specify the `@ConfigVersion` whenever you call `Import-Configuration` elsewhere in your module.

Note that configuration files are not currently deleted by Uninstall-Module, so they are never automatically cleaned up.

# How it works

The Configuration module works by serializing PowerShell hashtables or custom objects into PowerShell data language in a `Configuration.psd1` file!

## Configuration path

When you `Export-Configuration` you can set the `-Scope`, which determines where the Configuration.psd1 are stored:

* **User** exports to `$Env:LocalAppData` or `~/.config/`
* **Enterprise** exports to `$Env:AppData` (the roaming path) or `~/.local/share/`
* **Machine** exports to `$Env:ProgramData` or `/etc/xdg/`

Note that the linux paths are controlled by XDG environment variables, and the default paths can be overriden by mandually editing the Configuration module manifest.

Within that folder, the Configuration module root is "PowerShell," followed by either a company or author and the module name -- within which your configuration file(s) are stored.

From a module that uses Configuration, you can call the `Get-ConfigurationPath` command to get the path to that folder, and since the folder is created for you, you can use it store other files, like cached images, etc.

## Layered Configuration

In addition to automatically determining the storage path, the configuration module supports layered configuration, so that you can have defaults you ship with your module, or configure default at the enterprise or machine level, and still allow users to override the settings. When you call `Import-Configuration` from within a module, it automatically imports _all_ the available files and updates the configuration object which is returned at the end:

1. First, it imports the default Configuration.psd1 from the module's folder.
2. Then it imports machine-wide settings (e.g. the ProgramData folder)
3. Then it imports the users' enterprise roaming settings (e.g. from AppData\Roaming)
4. Finally it imports the users' local settings (from AppData\Local)

Any missing files are just skipped, and each layer of settings updates the settings from the previous layers, so if you don't set a setting in one layer, the setting from the previous layers persists.

However, it's up to individual users and module authors to take advantage of this..

## Serialization

The actual serialization commands (with the `Metadata` noun) are: ConvertFrom, ConvertTo, Import and Export.  By default, the Configuration serializer can handle a variety of custom PSObjects, hashtables, and arrays recursively, and has specific handling for booleans, strings and numbers, as well as Versions, GUIDs, and DateTime, DateTimeOffset, and even ScriptBlocks and PSCredential objects.

**Important note:** PSCredentials are stored using ConvertTo-SecureString, and currently only work on Windows. They should be stored in the user scope, since they're serialized per-user, per-machine, using the Windows Data Protection API.

In other words, it handles everything you're likely to need in a configuration file. However, it also has support for adding additional type serializers via the `Add-MetadataConverter` command. If you want to store anything that doesn't work, please raise an issue :wink:.

#### One little catch

The configuration module uses the caller's scope to determine the name of the module (and Company or Author name) that is asking for configuration.  For this reason you normally just call `Import-Configuration` from within _a function_ **in** your module (to make sure the callstack shows the module scope).

The _very important_ side effect is that you _must not_ change the module name nor the author of your module if you're using this Configuration module, or you will need to manually call `Import-Configuration` with the old information and then `Export` those settings to the new location (see the )

#### Using the cmdlets from outside a module

It is possible to use the commands to Import and Export the configuration for a module from outside the module (or from the main module body, instead of a function), simply pipe the ModuleInfo to `Import-Configuration`. To continue our example from earlier:

```posh
$Config = Get-Module DataModule | Import-Configuration
$Config.DriveName = "DataDrive"
Get-Module DataModule | Export-Configuration $Config
```

Note that if you look at the parameter sets for `Import-Configuration` you will find that you can also just pass the the `-Author` (or `-CompanyName`) and module `-Name` by hand, but you must be sure to get them exactly right, or you'll import nothing...

```posh
$Config = Import-Configuration -Name DataModule -Author HuddledMasses.org
```

Because of how easily this can go wrong, I strongly recommend you don't use this syntax -- but if you do, be aware that you must also specify the `-DefaultPath` if you want to load the default configuration file from the module folder.


# A little history:

The Configuration module is something I first wrote as part of the PoshCode packaging module and have been meaning to pull out for awhile.

I finally started working on this while I work on writing the Gherkin support for Pester. That support was  merged into Pester with the 4.0 release, and I'm using it for the tests in this module.

In any case, this module is mostly code ported from my PoshCode module as I develop the specs (the .feature files) and the Gherkin support to run them! Anything you see here has better than 95% code coverage in the feature and step files, which are executable via `Invoke-Gherkin`.

For the tests to work, you need to make sure that the module isn't already loaded, because the tests import it with the file paths mocked for testing:

```posh
Remove-Module Configuration -ErrorAction SilentlyContinue
Invoke-Gherkin -CodeCoverage *.psm1
```