This set of tasks perform WIKI management operations

## Update a WIKI Page


###Usage

- Source Folder e.g. $(build.sourcesdirectory)
- Target Folder e.g. $(build.artifactstagingdirectory)\$(ArtifactName)\BlackMarble.Victory.Services.DACPackage_Packaged
- File types e.g. *.dacpac
- Filter on e.g. a PowerShell filter

In effect this task wrappers [Get-ChildItem](https://technet.microsoft.com/en-us/library/hh849800.aspx), see this commands online documentation for the filtering options

This tasks would usually be followed by a 'Publish Build Artifacts' task to move the contents to the build drop.

## Releases

- 1.0 Initial release
