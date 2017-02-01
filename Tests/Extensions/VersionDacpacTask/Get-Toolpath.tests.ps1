# Load the script under test
. "$PSScriptRoot\..\..\..\extensions\versioning\versiondacpactask\Update-DacPacVersionNumber.ps1" 

Describe "Use SQL2012 ToolPath settings" {
    Mock Test-Path  {return $false} -ParameterFilter { 
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        } 
    Mock Test-Path  {return $true} -ParameterFilter { 
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        }     
 
    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath "" 
        $path | Should be "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"
    }
}

Describe "Use SQL2014 ToolPath settings" {
    Mock Test-Path  {return $true} -ParameterFilter { 
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        } 
       
    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath "" 
        $path | Should be "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"
    }
}


Describe "Use User ToolPath settings" {
    Mock Test-Path  {return $false} -ParameterFilter { 
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        } 

     Mock Test-Path  {return $false} -ParameterFilter { 
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        }     
       
      Mock Test-Path  {return $true} -ParameterFilter { 
            $Path -eq "C:\mocked\Microsoft.SqlServer.Dac.Extensions.dll"
        }  

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath "C:\mocked" 
        $path | Should be "C:\mocked"
    }
}


Describe "Cannot use User ToolPath settings" {
    Mock Test-Path  {return $false}
    Mock write-error -MockWith {return $msg -match "Mocked error"} -verifiable

    It "cannot Find DLLs" {
        Get-Toolpath -ToolPath "C:\dummy" 
        Assert-VerifiableMocks
    }
}