
- V1.0.0 - Original Release
- V1.2.x - Skipped
- V1.3.x - Added tool path choice for DACPACs
- V1.4.x - Added options for VSIX
- V1.5.x - Changed APPX regex filter
- V1.6.x - Make the regex filter a property for all tasks
    - Added a Nuspec tasks
- V1.7.x - Nuspec task Fixed UTF8
    - Nuspec task fixed Namespace Xpath issue
- V1.8.x - Added output variables for the version number actually used
- V1.9.x - Allow separate regex filters for extracting version and file handling in VersionAssemblies task
- V1.10.x - Fixed file encoding issue
- V1.11.x - Allows a filename pattern to be entered as a parameter for Assembly Versioning
- V1.12.x - Added versioning of Sharepoint Addin App Manifest
- V1.13.x - Added support for SQL2016 and VS2017 to DacPac task
- V1.14.x - DAC pack exclusing fixed
- V1.15.x - Added cross platform support for assebmly versioning
    - Added WIX versioning
- V1.16   - Fixed bug on .NETcore versioning
- V1.17   - Fixed bug with nuspec versioning that was not finding files in the root path.
- V1.18   - Issue 129
- V1.19   - Issue 160 with .NET Core and Standard Versioning
- V1.22   - Fixed Issue 166 with .NET Core not versioning csproj files targetting multiple frameworks.
    - Fixed Issue 167 with .NET Core versioning not applying correctly to nupkg and product version fields.
- V1.23   - Fixed Issue 183 which broke due to V1.22 changing default behaviour.
- V1.24   - Added task to version Android manifest files for Xamarin projects.
- V1.25   - Fixed Issue 176 where the task assumes the existing version number matches the provided version number (PR from @esbenbach)
          - Fixed Issue 185 where the task wasn't replacing existing version numbers correctly.
          - Fixed Issue 177 where the task wouldn't find assembly info files if they weren't in specific folders.
- V1.26   - Fixed Issue 197 where the task wouldn't correctly run on Hosted agents due to changes in the DacFx install location.
- V1.27   - Engineering Issue #202
- V1.28   - Issue #213 fix for UTF8 File encoding problems 
- V1.29   - Issue #217 moved the ANdroid versioner to NodeJS
- V1.30   - Issue #222 allowed more complex delimiters in version number format
- V1.31   - Issue #233 added JSON and Angular versioner
- V1.32   - Issue #254 allow version extraction to be bypassed for JSON Versioner 

A set of tasks based on the versioning sample script to version tamping assemblies shown in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow versioning of

* VersionAssemblies - sets the version in the assemblyinfo.cs or .vb (used pre build)
* VersionDotNetCoreAssemblies - sets the version in the .csproj (used pre build)
* VersionAPPX - sets the version in the Package.appxmanifest (used pre build)
* VersionVSIX - sets the version in the source.extension.vsixmanifest (used pre build)
* VersionDacpac - sets the version in a SQL DACPAC (used post build)
* VersionNuspec - sets the version in a Nuget Nuspec file (used pre packing)
* VersionSharePoint - sets the version in a SharePoint 2013/2016/O365 Add-In
* VersionWix - sets the version in a Wix Project
* VersionAndroidManifest - Sets the versionName and versionCode values in an Android project
* VersionJSONFile - Sets the version in a named field in a JSON file (tested in NPM package.json file)
* VersionAngularFile - Sets the version in a named field in an enviroment.ts Angular file

All these tasks take at least two parameters, which are both defaulted

* Path to files to version: Defaults to $(Build.SourcesDirectory)
* Version number: Defaults to $(Build.BuildNumber)
* [Advanced] Version Regex: The filter used to extract the version number from the build. Default to '\d+\.\d+\.\d+\.\d+'
* [Output] OutputVersion: Outputs the actual version number extracted from build number.

The Assembly & .NET Core versioner also takes the following Advanced option

* [Advanced] Field: The name of the version field to update, if blank updates all. Default is empty

The DACPAC versioner also takes the following Advanced option

* ToolPath: The path to the folder containing the files Microsoft.SqlServer.Dac.dll and Microsoft.SqlServer.Dac.Extensions.dll. This should be used if these files are not in the default location either C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120 or C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"

The VSIX versioner also takes the following parameters

* If the versionumber parameter is treated as a version number or a build number (from which the version needs to be extracted)
* If the discovered version should be trimmed to 2 digit field

The Android manifest versioner takes the following extra parameters:

* Version Name Pattern - This is the pattern you'd like the publicly visible version name to take in. This should be in the format {1}.{2} or similar but will also work with 1.2.3 etc.
* Version Code Pattern - This is the elements that you'd like to use to store the internal version number that Google uses for detecting if a version of the app is newer than an existing version, both in the play store and on the device. This will concatenate any specifies parts together into a single integer. It Accepts single values like {3} or multiple like {1}{2}{3}, delmiting with `{x}` is optional and should work with 123.
