# vNextBuild Tasks and Resources

This repo contains TFS vNext tasks and useful PowerShell scripts

## Build Tasks ##
### Typemock ###
A task that uses TMockRunner to wrapper the running of the standard VSTest console enabling Typemock Isolator based tests within TFS vNext build.
 
This task takes all the same argument as the standard VSTest build task (as it will normally be used as direct replacement for the VSTest task), with the addition of

- The company the instance of Typemock is licensed to
- The licensed key
- The path to the Typemock autodeployment folder in source control

A discussion of the development and usage of this Typemock task can be found in [this blog post](http://blogs.blackmarble.co.uk/blogs/rfennell/post/2015/09/08/Running-Typemock-Isolator-based-tests-in-TFS-vNext-build.aspx).

----------

For details of how to build and deploy these tasks see [this repo's wiki](https://github.com/rfennell/vNextBuild/wiki)

## Powershell Scripts ##
The following PowerScripts can be called from the standard TFS vNext build Powershell task to wrapper other tools without the need to create a custom task
 
- WebDeploy.ps1 - a script to wrapper WebDeploy replacing the contents of the setparameters.xml file. A discussion of this script can be found in [this blog post](http://blogs.blackmarble.co.uk/blogs/rfennell/post/2015/08/21/Using-Release-Management-vNext-templates-when-you-dont-want-to-use-DSC-scripts-A-better-script.aspx)
- DbDeploy.ps1 - a scrript to wrapper SQLPackage to deploy a .DACPAC. A discussion of this script can be found in [this blog post](http://blogs.blackmarble.co.uk/blogs/rfennell/post/2015/06/18/Using-Release-Management-vNext-templates-when-you-dont-want-to-use-DSC-scripts.aspx)
- TCMExecWrapper.ps1 - A wrapper to use TCM.EXE to trigger Microsoft Test Manager based tests, then setting a build tag based on the results of the test run. A discussion of this script can be found in [this blog post](http://blogs.blackmarble.co.uk/blogs/rfennell/post/2015/08/28/An-alternative-to-setting-a-build-quality-on-a-TFS-vNext-build.aspx)