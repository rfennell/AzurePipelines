# THIS PROJECT IS NOT UNDER ACTIVE DEVELOPMENT 
**As discussed in [this blog post](https://blogs.blackmarble.co.uk/rfennell/2020/05/03/announcing-the-deprecation-of-my-azure-devops-pester-extension-as-it-has-been-migrated-to-the-pester-project-and-republished-under-a-new-id/) this extension has been deprecated and it codebase migrated to a new home under the [Pester Project](https://github.com/pester/AzureDevOpsExtension). Please swap to using the new [updated cross-platform version of this extension](https://marketplace.visualstudio.com/items?itemName=Pester.PesterRunner) now published by the Pester Project**

<hr>

A task to install and run PowerShell Pester based tests
The task takes five parameters

The main ones are

- Folder to run scripts from e.g $(Build.SourcesDirectory)\\* or a script hashtable @{Path='$(Build.SourcesDirectory)'; Parameters=@{param1='111'; param2='222'}}"
- The results file name, defaults to $(Build.SourcesDirectory)\Test-Pester.XML.
- The code coverage file name, this outputs a JaCoCo XML file that the code coverage task can read. *Note: Requires Pester 4.0.4+*
- Tagged test cases to run.
- Tagged test cases to exclude from test run.

The advanced ones are

- Should the instance of PowerShell used to run the test be forced to run in 32bit, defaults to false.

The Pester task does not in itself upload the test results, it just throws an error if tests fails. It relies on the standard test results upload task.

So you also need to add the test results upload and set the following parameters

- Set it to look for nUnit format files
- It already defaults to the correct file name pattern.

IMPORTANT: As the Pester task will stop the build on an error you need to set the ‘Always run’ to make sure the results are published.

Once all this is added to your build you can see your Pester test results in the build summary

Releases
- 1.0.x - initial public release (targets Pester 3.3.5)
- 4.0.x - changed versioning to fit with new release pipeline (still targets Pester 3.4.0)
- 4.1.x - now targets 3.4.3, but allows the path to the module to be overriden
- 4.2.x.- removed non-required demand
- 4.3.x.- Added support for Tag and ExcludeTag parameters
- 4.4.x - Added support for multiple comma separated tags
- 5.0.x - Added optional support for Pester 4.0.3
- 5.1.x - Fixes issue with running tests using the 32Bit process switch (#150)
- 6.0.x - Add support for JaCoCo code coverage as provided by Pester 4.0.8 ([issue #152](https://github.com/rfennell/vNextBuild/issues/152))
- 6.1.x - Engineering updates, no functional change
- 6.2.x - Issue265 documentation change to show how other scripts can be used
- 6.3.x - Engineering test same as 7.0.x
- 7.0.x - PR287 changed included version of 4x Pester from 4.0.8 to 4.3.1, incremented major version as change of advanced options blocks auto update.
- 7.1.x - Added additionalModulePath and CodeCoverageFolder, to support testing compiled modules ([PR#285](https://github.com/rfennell/vNextBuild/pull/285))
- 7.2.x - Multiple fixes:
    - Fix check for code coverage folder being specified to ensure code coverage is generated from the correct files rather than files under $ScriptFolder. ([Fixes #330](https://github.com/rfennell/vNextBuild/issues/330))
    - Swap logging to use Write-Host to ensure it logs out by default. ([Fixes #320](https://github.com/rfennell/vNextBuild/issues/320))
    - Change Hashtable parsing function to use language parser to handle more cases. ([Fixes #321](https://github.com/rfennell/vNextBuild/issues/321))
- 8.0.x - Removed complicated version loading logic and replaced with installing the latest version from the gallery if you're on PSv5+ or have PowerShellGet available. If neither of those are options then it will load the 4.3.1 version of Pester that ships with the task. ([PR#314](https://github.com/rfennell/vNextBuild/pull/314))
- 8.1.x - Fixed the default working folder to System.DefaultWorkingDirectory as this is a variable available in both build and release. ([Fixes #350](https://github.com/rfennell/vNextBuild/issues/350))
- 8.3.x - Fixed the version number comparison for Code Coverage so it should no longer incorrectly warn when a version is newer than 4.0.4 [Fixes #356](https://github.com/rfennell/vNextBuild/issues/356)
- 8.4.x - Fixed the hashtable conversion for lower versions of PowerShell. Sadly this makes use of Invoke-Expression but there is a warning that it is an unsafe operation and the build agent should be upgraded to v5 when possible. [Fixes #358](https://github.com/rfennell/vNextBuild/issues/358)
- 8.6.x - Fixed the installation of Pester from the PSGallery to use the first available PS Repository so it handles situations where only a private repository is available. [Fixes #366](https://github.com/rfennell/vNextBuild/issues/366)
- 8.7.x - Fixed the installation of Pester to use whatever repository has the latest version available. This handles situations where the first private repository available doesn't have Pester or has an older version of Pester. [Fixes #366 Comment](https://github.com/rfennell/vNextBuild/issues/366#issuecomment-420618766)
- 8.8.x - Add ScriptBlock parameter to allow running a script before running the tests. [Fixes #377](https://github.com/rfennell/vNextBuild/issues/377)
- 8.11.x - Fixing Find-Module issues raised in [#412](https://github.com/rfennell/AzurePipelines/issues/412) and [415](https://github.com/rfennell/AzurePipelines/issues/415) by adding a check for AllowPrerelease switch on the cmdlet. If it's not available we'll fall back to the version of Pester that is shipped with the extension and write a warning that a newer version can't be used without a newer version of PowerShellGet being available.
- 8.12.x - Updating built in version of Pester to 4.6.0. Remove check for AllowPrerelease as it's not needed. Fixes [#421](https://github.com/rfennell/AzurePipelines/issues/421)
- 8.13.x - Update to better support offline build machines with no nuget installed. Falls back to shipped version of Pester. Fixes [#447](https://github.com/rfennell/AzurePipelines/issues/447)
