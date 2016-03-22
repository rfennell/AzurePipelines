A set of tasks based on the versioning sample script to version tamping assemblies shown in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow versioning of 

* VersionAssemblies - sets the version in the assemblyinfo.cs or .vb (used pre build)
* VersionAPPX - sets the version in the Package.appxmanifest (used pre build)
* VersionVSIX - sets the version in the source.extension.vsixmanifest (used pre build)
* VersionDacpac - sets the version in a SQL DACPAC (used post build)

All these tasks take two parameters, which are both defaulted

* Path to files to version: Defaults to $(Build.SourcesDirectory)
* Version number: Defaults to $(Build.BuildNumber)