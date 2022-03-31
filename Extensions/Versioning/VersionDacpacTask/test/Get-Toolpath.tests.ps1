Describe "Legacy version discovery" {

    BeforeEach {
        function Get-VstsInput { param ($Name) }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "Path" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionNumber" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ToolPath" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InjectVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionRegex" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "outputversion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VSVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "SDkVersion" } { return "" }

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2017"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Find SQL Server ToolPath" {
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0"
        }

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0"
        }

        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft SQL Server"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.Extensions.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft SQL Server"
        }

        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"

        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files\Microsoft SQL Server\120\DAC\bin"
    }


    It "Find VS2015 SQL2012 130 ToolPath" {
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0"
        }

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0"
        }

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft SQL Server"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll" }
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0"
        }

        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"

        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130"
    }


    It "Find VS2015 SQL2012 130 ToolPath" {
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 14.0"
        }

        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0"
        }

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft SQL Server"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.Extensions.dll" }
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.Extensions.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio 12.0"
        }

        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"

        $path = Get-Toolpath -ToolPath ""
        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130"
    }
}

Describe "Modern version discovery" {
    BeforeEach {
        function Get-VstsInput { param ($Name) }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "Path" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionNumber" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ToolPath" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InjectVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionRegex" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "outputversion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VSVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "SDkVersion" } { return "" }

        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Can request VS2017 SDK130" {

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2017"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        $path = Get-Toolpath -ToolPath "" -VSVersion "2017" -SDKVersion "130"

        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130"
    }

    It "Can request newest VS2017 SDK" {

        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2017"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        $path = Get-Toolpath -ToolPath "" -VSVersion "2017" -SDKVersion ""

        $path | Should -Be "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140"
    }

    It "Can request newest SDK" {

        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2017"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2022"
        }
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2019"
        }
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\Program Files (x86)\Microsoft Visual Studio\2017"
        }

        Mock Get-ChildItem {
            [PSCustomObject]@{FullName = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\130\Microsoft.SqlServer.Dac.dll" },
            [PSCustomObject]@{FullName = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\120\Microsoft.SqlServer.Dac.dll" }
        } -ParameterFilter {
            $Path -eq "C:\Program Files\Microsoft Visual Studio\2022"
        }

        $path = Get-Toolpath -ToolPath "" -VSVersion "" -SDKVersion ""

        $path | Should -Be "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140"
    }
}

Describe "Manual ToolPath" {
    BeforeEach {
        function Get-VstsInput { param ($Name) }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "Path" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionNumber" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "ToolPath" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "InjectVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VersionRegex" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "outputversion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "VSVersion" } { return "" }
        Mock Get-VstsInput -ParameterFilter { $Name -eq "SDkVersion" } { return "" }


        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
    }

    It "Can find valid Tool Path" {
        Mock Test-Path { return $true } -ParameterFilter {
            $Path -eq "C:\mocked\Microsoft.SqlServer.Dac.Extensions.dll"
        }

        $path = Get-Toolpath -ToolPath "C:\mocked"
        $path | Should -Be "C:\mocked"
    }

    It "Cannot Find manual tool path" {
        Mock Test-Path { return $false }
        Mock write-error -MockWith { return $msg -match "Mocked error" } -verifiable

        Get-Toolpath -ToolPath "C:\dummy"
        Assert-MockCalled write-error
    }
}
