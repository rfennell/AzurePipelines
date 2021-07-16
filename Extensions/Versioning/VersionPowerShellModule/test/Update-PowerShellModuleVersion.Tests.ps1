

$VerbosePreference = "continue"

Describe "Testing Update-PowerShellModuleVersion.ps1" {

    BeforeEach {
        $sut = Join-Path -Path $PSScriptRoot -ChildPath '..\src\Update-PowerShellModuleVersion.ps1' -Resolve
        function Get-VstsInput {param ($Name)}

        Function Update-MetaData {}
        Function Get-MetaData {}
#        Mock -CommandName Write-Verbose -MockWith {}
        Mock -CommandName Write-Warning -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
        Mock -CommandName Get-PackageProvider -MockWith {}
        Mock -CommandName Install-PackageProvider -MockWith {}
        Mock Find-Module {
                [PsCustomObject]@{Version=[version]::new(4,3,0);Repository='OtherRepository'}
        }
        Mock -CommandName Install-Module -MockWith {}
        Mock -CommandName Import-Module -MockWith {}
        Mock -CommandName Update-MetaData -MockWith {}
        Mock -CommandName Write-Host -MockWith {}
        Mock -CommandName Get-ChildItem -MockWith {@(
            [PSCustomObject]@{
                Fullname = 'TestDrive:\First.psd1'
            },
            [PSCustomObject]@{
                Fullname = 'TestDrive:\Second.psd1'
            }
        )}
        Mock -CommandName Select-String -MockWith {
            [PSCustomObject]@{
                Path = 'TestDrive:\First.psd1'
            }
        }
        Mock -CommandName Get-MetaData -MockWith {$true}
        #Mock -CommandName Select-Object -MockWith {}
    }

    It "Should write an error when the version number isn't a valid format" {
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return 'TestDrive:\First.psd1'}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return "FakeNumber"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return "true"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return "\d+\.\d+\.\d+\.\d+"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        &$Sut
        Assert-MockCalled -CommandName Write-Error -Scope It -Times 1
    }

    It "Should attempt to update 1 module in the target path" {
        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return 'TestDrive:\'}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return "1.2.3.4"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return "true"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return "\d+\.\d+\.\d+\.\d+"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        Mock -CommandName Select-Object -MockWith {'TestDrive:\First.psd1'} -ParameterFilter {$InputObject.Path -eq 'TestDrive:\First.psd1'}

        &$Sut

        Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 1
    }
    It "Should attempt to update 2 modules in the target path" {

        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return 'TestDrive:\'}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return "1.2.3.4"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return "true"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return "\d+\.\d+\.\d+\.\d+"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}

        &$Sut

        Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 2
    }
    It "Should attempt to update the version number and private data in 1 module in the target path when a prerelease version is passed" {

        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return 'TestDrive:\'}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return "1.2.3.4-alpha"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return "true"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return "\d+\.\d+\.\d+\.\d+"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
        Mock -CommandName Select-Object -MockWith {'TestDrive:\First.psd1'} -ParameterFilter {$InputObject.Path -eq 'TestDrive:\First.psd1'}

        &$Sut

        Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 2
    }
    It "Should write a warning when the PSData Prerelease section isn't in the manifest when a prerelease version is passed" {

        Mock Get-VstsInput -ParameterFilter {$Name -eq "Path"} {return 'TestDrive:\'}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionNumber"} {return "1.2.3.4-alpha"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "InjectVersion"} {return "true"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "VersionRegex"} {return "\d+\.\d+\.\d+\.\d+"}
        Mock Get-VstsInput -ParameterFilter {$Name -eq "outputversion"} {return ""}
        Mock -CommandName Select-Object -MockWith {'TestDrive:\First.psd1'} -ParameterFilter {$InputObject.Path -eq 'TestDrive:\First.psd1'}
        Mock -CommandName Get-MetaData -MockWith {$null}
        &$Sut

        Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 1
        Assert-MockCalled -CommandName Write-Warning -Scope It -Times 1 -ParameterFilter {
            $Message -eq ("Cannot set Prerelease in module manifest. Add an empty Prerelease to your module manifest, like:`n" +
            '         PrivateData = @{ PSData = @{ Prerelease = "" } }')
        }
    }
}

