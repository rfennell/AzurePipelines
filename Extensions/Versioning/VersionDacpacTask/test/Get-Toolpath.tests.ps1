Describe "Use VS2013 SQL2012 120 ToolPath settings" {

    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        Mock Test-Path  {return $false} -ParameterFilter {
                $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
            }
        Mock Test-Path  {return $false} -ParameterFilter {
                $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
            }
        Mock Test-Path  {return $false} -ParameterFilter {
                $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll"
            }
        Mock Test-Path  {return $true} -ParameterFilter {
                $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
            }
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"
    }
}

Describe "Use VS2015 SQL2014 120 ToolPath settings" {
    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        Mock Test-Path  {return $false} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        Mock Test-Path  {return $false} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll"
        }

        Mock Test-Path  {return $true} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        }
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120"
    }
}

Describe "Use VS2015 SQL2014 130 ToolPath settings" {
    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
    
        Mock Test-Path  {return $false} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }
    
        Mock Test-Path  {return $true} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll"
        }
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130"
    }
}

Describe "Use VS2017 SQL2014 130 ToolPath settings" {
    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
    
        Mock Test-Path  {return $true} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }
    
        Mock Get-ChildItem {return "DevSku"} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }
    
        Mock Test-Path  {return $true} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017\DevSku\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll"
        }
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio\2017\DevSku\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130"
    }
}


Describe "Use User ToolPath settings" {
    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        Mock Test-Path  {return $false} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        }


        Mock Test-Path  {return $false} -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll"
        }


        Mock Test-Path  {return $true} -ParameterFilter {
            $Path -eq "C:\mocked\Microsoft.SqlServer.Dac.Extensions.dll"
        }
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find DLLs" {
        $path = Get-Toolpath -ToolPath "C:\mocked"
        $path | Should -Be "C:\mocked"
    }
}


Describe "Cannot use User ToolPath settings" {
    BeforeEach {
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
        Mock Test-Path  {return $false}
        Mock write-error -MockWith {return $msg -match "Mocked error"} -verifiable
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "cannot Find DLLs" {
        Get-Toolpath -ToolPath "C:\dummy"
        Assert-MockCalled write-error
    }
}
