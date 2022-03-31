
A set of tasks based on the versioning sample script to version stamp assemblies shown in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow versioning of

* VersionAssemblies - sets the version in the assemblyinfo.cs or .vb (used pre build)
* VersionDotNetCoreAssemblies - sets the version in the .csproj (used pre build)
* VersionAPPX - sets the version in the Package.appxmanifest (used pre build)
* VersionVSIX - sets the version in the source.extension.vsixmanifest (used pre build)
* VersionDacpac - sets the version in a SQL DACPAC (used pre or post build)
* VersionNuspec - sets the version in a Nuget Nuspec file (used pre packing)
* VersionSharePoint - sets the version in a SharePoint 2013/2016/O365 Add-In
* VersionWix - sets the version in a Wix Project
* VersionAndroidManifest - Sets the versionName and versionCode values in an Android project
* VersionJSONFile - Sets the version in a named field in a JSON file (tested in NPM package.json file)
* VersionAngularFile - Sets the version in a named field in an enviroment.ts Angular file
* VersionPowerShellModule - Sets the ModuleVersion property in any module psd1 files.
* VersionIOSPlistManifest - Sets the CFBundleShortVersionString and CFBundleVersion properties in iOS Plist files.

All these tasks take at least two parameters, which are both defaulted

* Path to files to version: Defaults to $(Build.SourcesDirectory)
* Version number: Defaults to $(Build.BuildNumber)
* [Advanced] Inject Version: If true then the build number will be used without regex processing
* [Advanced] Version Regex: The filter used to extract the version number from the build. Default to '\d+\.\d+\.\d+\.\d+'
* [Output] OutputVersion: Outputs the actual version number extracted from build number.

The Assembly & .NET Core versioner also takes the following Advanced option

* [Advanced] Field: The name of the version field to update, if blank updates all. Default is empty

The .NET Core versioner also takes the following Advanced option

* [Advanced] FilenamePattern: The filename pattern to update. Default to .csproj or can be directory.build.props
* [Advanced] SDKNames: A comma separated list of SDK namespaces to use to match .csproj file. Ignored if filename pattern is directory.build.props

The WIX versioner also takes the following Advanced options

* [Advanced] FieldsToMatch: The list of five field names that will be updated in the wxi file, defaults to 'MajorVersion,MinorVersion,BuildNumber,Revision,FullVersion'

The DACPAC versioner also takes the following Advanced option

* The task can now be run pre-build similar to the other versioning tasks and will set the DacVersion property in the SqlProj file to the required version number.
* ToolPath: The path to the folder containing the files Microsoft.SqlServer.Dac.dll and Microsoft.SqlServer.Dac.Extensions.dll. This should be used if these files are not in the default location and hence cannot be found by the task. This value takes precedence over the automated means of finding the DLL
* VSVersion: A filter for the Visual Studio version to scan for the SQL DAC SDK e.g 2017, 2015, 2022. if not set will scan for all versions and the newest used.
* SDKVersion: A filter for the SQL DAC SDK e.g 130, 150. if not set will scan for all versions and the newest used.

The VSIX versioner also takes the following parameters

* If the versionumber parameter is treated as a version number or a build number (from which the version needs to be extracted)
* If the discovered version should be trimmed to 2 digit field

The Android manifest versioner takes the following extra parameters:

* [Advanced] Inject Version Code: If true then the provided version code will be used as opposed generating from the build number will regex processing
* Version Code - A number between 1 and 2100000000 as required by the Google Play Store
* Version Name Pattern - This is the pattern you'd like the publicly visible version name to take in. This should be in the format {1}.{2} or similar but will also work with 1.2.3 etc.
* Version Code Pattern - This is the elements that you'd like to use to store the internal version number that Google uses for detecting if a version of the app is newer than an existing version, both in the play store and on the device. This will concatenate any specifies parts together into a single integer. It Accepts single values like {3} or multiple like {1}{2}{3}, delmiting with `{x}` is optional and should work with 123.

See the blog post [Making sure when you use VSTS build numbers to version Android Packages they can be uploaded to the Google Play Store](https://blogs.blackmarble.co.uk/rfennell/2018/05/12/making-sure-when-you-use-vsts-build-numbers-to-version-android-packages-they-can-be-uploaded-to-the-google-play-store/) for more details on using this task

The JSON and Angular versioners use the same form of format parameter as the android versioner for the version number to write to the file

The Plist manifest version takes the following extra parameters:
* [Advanced] Inject CFBundleShortVersionString: If true then the provided CFBundleShortVersionString will be used as opposed generating from the build number will regex processing
* [Advanced] Inject CFBundleVersion: If true then the provided CFBundleVersion will be used as opposed generating from the build number will regex processing
* CFBundleShortVersionString Pattern - This is the pattern you'd like the publicly visible version name to take in. This should be in the format {1}.{2} or similar but will also work with 1.2.3 etc.
* CFBundleVersion Pattern - This is the pattern you'd like the publicly visible version name to take in. This should be in the format {1}.{2} or similar but will also work with 1.2.3 etc.
* Version Code Pattern - This is the elements that you'd like to use to store the internal version number that Google uses for detecting if a version of the app is newer than an existing version, both in the play store and on the device. This will concatenate any specifies parts together into a single integer. It Accepts single values like {3} or multiple like {1}{2}{3}, delmiting with `{x}` is optional and should work with 123.
