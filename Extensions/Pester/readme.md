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
- (New in 5.x) You can pick if the Pester 3.4.3 or 4.3.1 modules (both are included in the task) are used
- If neither 3.4.3 or 4.3.1 is suitable then a custom module path pointing to where the required Pester.psd1 and related files are stored can be entered. This will be used in preference to the embedded versions

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