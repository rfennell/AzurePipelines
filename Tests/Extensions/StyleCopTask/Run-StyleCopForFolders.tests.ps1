if ($env:Processor_Architecture -ne "x86")   
{ write-warning 'Launching x86 PowerShell'
&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $myinvocation.Mycommand.path -executionpolicy bypass
exit
}
write-verbose "Running in 32bit PowerShell at this point as dictionaries loaded by StyleCop are 32bit only."


# Check that the required powershell module is loaded if it is remove it as it might be an older version
if ((get-module -name StyleCop ) -ne $null)
{
  remove-module StyleCop 
} 
import-module "$PSScriptRoot\..\..\..\extensions\stylecop\stylecoptask\StyleCop.psm1"

# Make sure we have a log folder
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" >$null 2>&1



Describe "StyleCop folder based tests" {
  
    It "Solution has 49 issues" {
        $result = Invoke-StyleCopForFolderStructure -sourcefolder "$PSScriptRoot\testdata\StyleCopSample" `
                                  -loggingfolder "$PSScriptRoot\logs"                                   
        $result.OverallSuccess | Should be $true
        $result.TotalViolations | Should be 49
        $result.ProjectsScanned | Should be 2
    }
}

