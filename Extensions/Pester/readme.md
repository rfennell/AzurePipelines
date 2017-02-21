Releases
- 1.0.x - initial public release (targets Pester 3.3.5)
- 4.0.x - changed versioning to fit with new release pipeline (still targets Pester 3.4.0)
- 4.1.x - now targets 3.4.3, but allows the path to the module to be overriden
- 4.2.x.- removed non-required demand
- 4.3.x.- Added support for Tag and ExcludeTag parameters

A task to install and run PowerShell Pester based tests 
The task takes five parameters 

- The root folder to look for test scripts with the naming convention  *.tests.ps1. Defaults to $(Build.SourcesDirectory)\*
- The results file name, defaults to $(Build.SourcesDirectory)\Test-Pester.XML. 
- Tagged test cases to run.
- Tagged test cases to exclude from test run.
- Should the instance of PowerShell used to run the test be forced to run in 32bit, defaults to false.
- Custom module path should Pester be stored in a non-standard location, not mandatory and defaults to the installed version of pester or the version provided with the extension if not installed already.

The Pester task does not in itself upload the test results, it just throws an error if tests fails. It relies on the standard test results upload task. 

So you also need to add the test results upload and set the following parameters

- Set it to look for nUnit format files
- It already defaults to the correct file name pattern.

IMPORTANT: As the Pester task will stop the build on an error you need to set the ‘Always run’ to make sure the results are published.

Once all this is added to your build you can see your Pester test results in the build summary