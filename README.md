![Build Status](https://richardfennell.visualstudio.com/DefaultCollection/_apis/public/build/definitions/670b3a60-2021-47ab-a88b-d76ebd888a2f/12/badge)

# vNextBuild Tasks and Resources

This repo contains TFS vNext tasks and useful PowerShell scripts

## Building Tasks ##

For details of how to build and deploy these tasks see [this repo's wiki](https://github.com/rfennell/vNextBuild/wiki/Build-Tasks)

## Included Tasks in the Repo##

- Typemock - A task that uses TMockRunner to wrapper the running of the standard VSTest console enabling Typemock Isolator based tests within TFS vNext build.
- UpdateWebDeployParameters - Update the contents of a singleSetParameters.XML file using tokenised environment variables
- StyleCop - A tasks to run StyleCop code analysis

A set of tasks that wrapper versions of the sample script to version assemblies show in the [VSTS documentation](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index
). These allow 

- VersionAssemblies - Sets the version in the assemblyinfo.cs or .vb
- VersionVSIX - Sets the version in the source.extension.vsixmanifest
- VersionAPPX - Sets the version in the Package.appxmanifest
- VersionDacpac - Sets the version in a SQL DACPAC (submitted by [Chris Gardner] 

----------

## Powershell Scripts ##
The following PowerScripts can be called from the standard TFS vNext build Powershell task to wrapper other tools without the need to create a custom task
 
- WebDeploy.ps1 - a script to wrapper WebDeploy replacing the contents of the setparameters.xml file. 
- DbDeploy.ps1 - a scrript to wrapper SQLPackage to deploy a .DACPAC. 
- TCMExecWrapper.ps1 - A wrapper to use TCM.EXE to trigger Microsoft Test Manager based tests, then setting a build tag based on the results of the test run. 
- ApplyVersionToAssemblies.ps1 - Just a copy of the script from [MSDN post](https://msdn.microsoft.com/Library/vs/alm/Build/scripts/index) so that I have scripts I commonly use in one place
- ApplyVersionToVSIX.ps1 - Using the same environment variable based system as ApplyVersionToAssemblies.ps1, this script sets the of a VSIX package in the for 1.2 (3rd and 4th parts of the version are discarded). 
- Update-DacpacVersionNumber.ps1 - A script to apply a specified version number to all dacpac files under the target folder. 
