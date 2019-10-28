# THIS PROJECT IS NOT UNDER ACTIVE DEVELOPMENT 
## AS RECOMMENDED ON [STYLECOP REPO](https://github.com/StyleCop/StyleCop) LOOK ELSEWHERE FOR ANALYSIS TOOLS AS STYLECOP IS BECOMING INCREASING HARD TO KEEP UP TOO DATE. [SONARQUBE](https://www.sonarqube.org) IS A GOOD FIRST PLACE TO LOOK

### StyleCop Runner Task ###
A task to run [StyleCop 6.1.0](https://www.nuget.org/packages/StyleCop/), not the older series of versions [on codeplex](https://stylecop.codeplex.com/)

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

Major Releases
- 1.1 First public release
- 1.2 Updated with StyleCOp 4.7.59.0
- 2.0 PR171 (thomasddn) - Upgrade to StyleCop 5.0.6419.0 and some engineering (Issue #202) restructoring of the repo to improve testing. Note that this version does not evaluate dictionary based tests i.e. SA1650. This has been done a major release so users get the choice of which version of StyleCop to use V1 of the task for StyleCop 4.7.59.0 and V2 for StyleCop 5.0.6419.0
- 3.0 #408 - Upgraded to StyleCop 6.1.0