V1.0.0 - Original Release
V1.2.x - Skipped
V1.3.x - Added tool path choice for DACPACs
V1.4.x - Added options for VSIX
V1.5.x - Changed APPX regex filter
V1.6.x - Make the regex filter a property for all tasks
         Added a Nuspec tasks
V1.7.x - Nuspec task Fixed UTF8 
         Nuspec task fixed Namespace Xpath issue
V1.8.x - Added output variables for the version number actually used
V1.9.x - Allow separate regex filters for extracting version and file handling in VersionAssemblies task
V1.10.x - Fixed file encoding issue
V1.11.x - Allows a filename pattern to be entered as a parameter for Assembly Versioning

A set of tasks based on the versioning sample script to version tamping assemblies shown in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow versioning of 

* VersionAssemblies - sets the version in the assemblyinfo.cs or .vb (used pre build)
* VersionAPPX - sets the version in the Package.appxmanifest (used pre build)
* VersionVSIX - sets the version in the source.extension.vsixmanifest (used pre build)
* VersionDacpac - sets the version in a SQL DACPAC (used post build)
* VersionNuspec - sets the version in a Nuget Nuspec file (used pre packing)

All these tasks take at least two parameters, which are both defaulted

* Path to files to version: Defaults to $(Build.SourcesDirectory)
* Version number: Defaults to $(Build.BuildNumber)
* [Advanced] Version Regex: The filter used to extract the version number from the build. Default to '\d+\.\d+\.\d+\.\d+'
* [Output] OutputVersion: Outputs the actual version number extracted from build number. 

The Assembly versioner also takes the following Advanced option

* [Advanced] Field: The name of the version field to update, if blank updates all. Default is empty

The DACPAC versioner also takes the following Advanced option

* ToolPath: The path to the folder containing the files Microsoft.SqlServer.Dac.dll and Microsoft.SqlServer.Dac.Extensions.dll. This should be used if these files are not in the default location either C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120 or C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"

The VSIX versioner also tasks the following parameters

* If the versionumber parameter is treated as a version number or a build number (from which the version needs to be extracted)
* If the discovered version should be trimmed to 2 digit field
