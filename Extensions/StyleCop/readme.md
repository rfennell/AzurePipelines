### StyleCop Runner Task ###
A task to run [StyleCop 4.7.52.0](https://stylecop.codeplex.com/),

The task takes the following arguments
- TreatStyleCopViolationsErrorsAsWarnings - Treat StyleCop violations errors as warnings (default false).

And on the advanced panel
- MaximumViolationCount - Maximum violations before analysis stops (default 1000)
- ShowOutput - Sets the flag so StyleCop scanner outputs progress to the console (default false)
- CacheResults - Cache analysis results for reuse (default false)
- ForceFullAnalysis - Force complete re-analysis (default true)
- AdditionalAddInPath - Path to any custom rule sets folder, the directory cannot be a sub directory of current directory at runtime as this is automatically scanned. This folder must contain your custom DLL and the Stylecop.dll and Stylecop.csharp.cs
- SettingsFile - Path to single settings files to use (as opposed to settings.stylecop files in project folders, default empty)
- LoggingFolder - Folder to place the detailed text and XML formated log files (default the staging folder)