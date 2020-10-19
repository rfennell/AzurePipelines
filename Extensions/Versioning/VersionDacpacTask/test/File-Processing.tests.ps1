Describe "Issue 603 - Encoding of SQLproj files" {

    BeforeEach {
        # set up mocks
        function Get-VstsInput {param ($Name)}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "ToolPath"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return ""}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
        
        # Load the script under test
        import-module "$PSScriptRoot\..\src\Update-DacPacVersionNumber.ps1"
        $file = "$PSScriptRoot\testdata\Issue603.sqlproj"
        Write-Host "before each $file"
        Copy-Item "$PSScriptRoot\testdata\Issue603.sqlproj.initial" $file
    }

    It "Update Version" {
        $file = "$PSScriptRoot\testdata\Issue603.sqlproj"
        Update-SqlProjVersion -Path $file -VersionNumber "9.9.9.9" -regexpattern "\d+\.\d+\.\d+\.\d+"
        $expected = get-content "$PSScriptRoot\testdata\Issue603.sqlproj.expected" -Encoding UTF8
        $actual = get-content $file -Encoding UTF8
        $expected | Should -Be $actual
    }

    AfterEach {
       Remove-item $file
    }
}


