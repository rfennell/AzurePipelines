A set of tasks based on the versioning sample script to version assemblies shown in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow

* VersionAssemblies - sets the version in the assemblyinfocs or .vb
* VersionVSIX - sets the version in the source.extension.vsixmanifest
* VersionAPPX - sets the version in the Package.appxmanifest
* VersionDacpac - sets the version in a SQL DACPAC 

All these tasks take two parameters, which are both defaulted

* Path to files to version: Defaults to $(Build.SourcesDirectory)
* Version number: Defaults to $(Build.BuildNumber)