### StyleCop Runner Task ###
A task to run [StyleCop 5.0.6419.0](https://www.nuget.org/packages/StyleCop/), not the older series of versions [on codeplex](https://stylecop.codeplex.com/)

Releases
- 1.1 First public release
- 1.2 Updated with StyleCOp 4.7.59.0
- 1.6 (Skipped previous point releases whilst migrating to release pipeline) fixes dictionary loading issues due to 64/32bit handling
- 1.7 Altered logging to make some warning messages verbose messages as they are not issues
- 1.8 Altered logging to provide more data to debug end user issue, no functional change
- 1.9 Fixed issue with loading settings files from project folder (pull request from @amjrsl)
      Added custom dictionaries to avoid name matching false errors (pull request from @amjrsl) 
- 1.10 Fixed issues with discovering settings.stylecop files in solution folder (Issue #104)
- 1.11 Added parameter for adding allowable violations, which sets a threshold of acceptable number of violations (pull request from @jynxeh)
- 1.12 Fixed 'Test Warnings as Errors' flag being ignored (pull request from @jynxeh)
- 2.0 PR171 (thomasddn) - Upgrade to StyleCop 5.0.6419.0 and some engineering (Issue #202) restructoring of the repo to improve testing. Note that this version does not evaluate dictionary based tests i.e. SA1650. This has been done a major release so users get the choice of which version of StyleCop to use V1 of the task for StyleCop 4.7.59.0 and V2 for StyleCop 5.0.6419.0
- 2.1 Added an advanced flag that allows a detailed list of volitons (Issue #175)
- 2.2 Fixed Typo (PR#283)

The task takes the following arguments
- TreatStyleCopViolationsErrorsAsWarnings - Treat StyleCop violations errors as warnings (default false).

And on the advanced panel
- MaximumViolationCount - Maximum violations before analysis stops (default 1000)
- AllowableViolationCount - Threshold of violations to allow, still reports on which ones occured. (default 0)
- ShowOutput - Sets the flag so StyleCop scanner outputs progress to the console (default false)
- CacheResults - Cache analysis results for reuse (default false)
- ForceFullAnalysis - Force complete re-analysis (default true)
- AdditionalAddInPath - Path to any custom rule sets folder, the directory cannot be a sub directory of current directory at runtime as this is automatically scanned. This folder must contain your custom DLL and the Stylecop.dll and Stylecop.csharp.cs
- SettingsFile - Path to single settings files to use (as opposed to settings.stylecop files in project folders, default empty)
- LoggingFolder - Folder to place the detailed text and XML formated log files (default the staging folder)
