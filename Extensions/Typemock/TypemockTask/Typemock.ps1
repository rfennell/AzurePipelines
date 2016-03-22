param
(
	[string]$vsTestVersion, 
	[string]$testAssembly,
	[string]$testFiltercriteria,
	[string]$runSettingsFile,
	[string]$codeCoverageEnabled,
	[string]$pathtoCustomTestAdapters,
	[string]$overrideTestrunParameters,
	[string]$otherConsoleOptions,
	[string]$platform,
	[string]$configuration,

	[string]$license,
	[string]$company,
	[string]$autodeploypath

)


function GetVSTest
{
	param
	(
		[string]$requiredVersion
	)

    if (![string]::IsNullOrEmpty($requiredVersion))
	{
		"C:\Program Files (x86)\Microsoft Visual Studio $requiredVersion\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
	} else {
		$mstest = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
	}

	return $mstest
}

$VerbosePreference ='Continue' # equiv to -verbose
Write-Verbose "Entering script Typemock.ps1"

Write-Verbose "Typemock Isolator licensed to '$company'"
Write-Verbose "Typemock Isolator path '$autodeploypath'"

# Import the Task.Common dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
# Import the Task.TestResults dll that has the cmdlet we need for publishing results
import-module "Microsoft.TeamFoundation.DistributedTask.Task.TestResults"

if (!$testAssembly)
{
	throw "testAssembly parameter not set on script"
}

# check for solution pattern
if ($testAssembly.Contains("*") -or $testAssembly.Contains("?"))
{
	Write-Verbose "Pattern found in solution parameter. Calling Find-Files."
	Write-Verbose "Calling Find-Files with pattern: $testAssembly"
	$testAssemblyFiles = Find-Files -SearchPattern $testAssembly
	Write-Verbose "Found files: $testAssemblyFiles"
}
else
{
	Write-Verbose "No Pattern found in solution parameter."
	$testAssemblyFiles = ,$testAssembly
}

$codeCoverage = Convert-String $codeCoverageEnabled Boolean

if($testAssemblyFiles)
{
	Write-Verbose -Verbose "Calling VSTest via TMockRunner for all test assemblies"

	$workingDirectory = $env:AGENT_BUILDDIRECTORY
	$testResultsDirectory = $workingDirectory + "\" + "TestResults"

	# put us in thew correct folder
	Write-Verbose "Working directory is '$workingDirectory'"
	Set-Location -Path $workingDirectory
	Write-Verbose -Verbose "Test results to be stored in $testResultsDirectory"

	# Build the command line parameter
	$commandLineParams = ""
	foreach	($file in $testAssemblyFiles)
	{
		$commandLineParams += """$file"" ";
	}

	if (![string]::IsNullOrEmpty($testFiltercriteria))
	{
		$commandLineParams +=" /TestCaseFilter:$testFiltercriteria";
	}

	
	if (![string]::IsNullOrEmpty($runSettingsFile) -and  [System.IO.Path]::HasExtension($runSettingsFile))
	{
		if (!Test-Path($runSettingsFile))
		{
			Write-Warning ("Run settings file does not exist on: $runSettingsFile");
		}
		elseif (![string]::IsNullOrEmpty($overrideTestrunParameters) -or ![string]::IsNullOrEmpty($testResultsDirectory))
		{
		   $commandLineParams += " /Settings:""$runSettingsFile"""
		}
		else
		{
			if (!Test-Path($testResultsDirectory))
			{
				[System.IO.Directory]::CreateDirectory($testResultsDirectory);
			}
			$resultsFile 
			$str = [System.IO.Path]::Combine($testResultsDirectory, [System.IO.Path]::GetFileNameWithoutExtension($runSettingsFile), "_", [string]::Format("{0:yyyy-MM-dd_hh-mm-ss-tt}", [System.DateTime]::Now),[System.IO.Path]::GetExtension($runSettingsFile))
			[xml]$xmlDocument = Get-Content $runSettingsFile
			if (![string]::IsNullOrEmpty($overrridingParameters))
            {
				[xml]$xmlDocument = Get-Content $runSettingsFile
			    foreach ($parameter in $overrridingParameters.Split(';')) 
				{
					$param = $parameter.Split('=') 
					if ($param[1] -ne $null)
					{
						$node = $xmlDocument.RunSettings.TestRunParameters.Parameter | Where {$_.name -eq $param[0]}
						if ($node -ne $null)
						{
							$node.value = $param[1]
						}
					}
				}
				$xmlDocument.Save($str)
			}
			$commandLineParams +=" /Settings:""$str"""
		}
	}
	
	if (![string]::IsNullOrEmpty($pathtoCustomTestAdapters))
	{
		$commandLineParams +=" /TestAdapterPath:$pathtoCustomTestAdapters"
	}

	if ($codeCoverageEnabled -eq $true)
	{
	    $commandLineParams +=" /EnableCodeCoverage"
	}
	
	if (![string]::IsNullOrEmpty($otherConsoleOptions))
	{
	   $commandLineParams +=" $otherConsoleOptions"
	}
		
	$commandLineParams += " /logger:trx"


	# get the version of VS
	$mstest = GetVSTest -requiredVersion $vsTestVersion

		Write-Verbose "Using EXE '$mstest'"
	Write-Verbose "Using parameters '$commandLineParams'"

	
	# Invoke-VSTest -TestAssemblies $testAssemblyFiles -VSTestVersion $vsTestVersion -TestFiltercriteria $testFiltercriteria -RunSettingsFile $runSettingsFile -PathtoCustomTestAdapters $pathtoCustomTestAdapters -CodeCoverageEnabled $codeCoverage -OverrideTestrunParameters $overrideTestrunParameters -OtherConsoleOptions $otherConsoleOptions -WorkingFolder $workingDirectory -TestResultsFolder $testResultsDirectory
	& "$autodeploypath\tmockrunner.exe" -register "$company" "$license" $mstest $commandLineParams

	$resultFiles = Find-Files -SearchPattern "*.trx" -RootFolder $testResultsDirectory 

	Publish-TestResults -Context $distributedTaskContext -TestResultsFiles $resultFiles -TestRunner "VSTest" -Platform $platform -Configuration $configuration

}
else
{
	Write-Verbose "No test assemblies found matching the pattern: $testAssembly"
}
Write-Verbose "Leaving script Typemock.ps1"