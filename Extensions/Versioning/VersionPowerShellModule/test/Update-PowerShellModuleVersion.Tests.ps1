$sut = Join-Path -Path $PSScriptRoot -ChildPath '..\src\Update-PowerShellModuleVersion.ps1' -Resolve

Describe "Testing Update-PowerShellModuleVersion.ps1" {

    Context "Testing Inputs" {
        It "Should have Path as a mandatory parameter" {
            (Get-Command $Sut).Parameters['Path'].Attributes.mandatory | Should -Be $true
        }
        It "Should have VersionNumber as a mandatory parameter" {
            (Get-Command $Sut).Parameters['VersionNumber'].Attributes.mandatory | Should -Be $true
        }
        It "Should not have OutputVersion as a mandatory parameter" {
            (Get-Command $Sut).Parameters['OutputVersion'].Attributes.mandatory | Should -Be $false
        }
    }

    Context "Testing Processing" {
        Function Update-MetaData {}
        Mock -CommandName Write-Verbose -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
        Mock -CommandName Get-PackageProvider -MockWith {}
        Mock -CommandName Install-PackageProvider -MockWith {}
        Mock -CommandName Find-Module -MockWith {}
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
        Mock -CommandName Select-Object -MockWith {}

        It "Should write an error when the version number isn't a valid format" {
            &$Sut -Path TestDrive:\ -VersionNumber 'FakeNumber'
            Assert-MockCalled -CommandName Write-Error -Scope It -Times 1
        }
        It "Should install NuGet if it isn't already installed" {
            Mock -CommandName Get-PackageProvider -MockWith { Throw }

            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'

            Assert-MockCalled -CommandName Install-PackageProvider -Scope It -Times 1
        }
        It "Should install the latest version of Configuration when a newer version is available on the Gallery" {
            Mock -CommandName Find-Module -MockWith { [PsCustomObject]@{Version='9.9.9.9'}}

            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'

            Assert-MockCalled -CommandName Install-Module -Scope It -Times 1
        }
        It "Should not install a new version of Configuration when it is already available locally" {
            Mock -CommandName Find-Module -MockWith { [PsCustomObject]@{Version=[Version]::Parse('0.0.0.0')}}
            Mock -CommandName Select-Object -MockWith {[PsCustomObject]@{Version=[Version]::Parse('1.1.1.1')}} -ParameterFilter {$InputObject.Name -eq 'Configuration'}

            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'

            Assert-MockCalled -CommandName Install-Module -Scope It -Times 0
        }
        It "Should attempt to update 1 module in the target path" {
            Mock -CommandName Select-Object -MockWith {'TestDrive:\First.psd1'} -ParameterFilter {$InputObject.Path -eq 'TestDrive:\First.psd1'}

            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'

            Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 1
        }
        It "Should attempt to update 2 modules in the target path" {
            Mock -CommandName Select-Object -MockWith {@('TestDrive:\First.psd1','TestDrive:\Second.psd1')} -ParameterFilter {$InputObject.Path -eq 'TestDrive:\First.psd1'}

            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'

            Assert-MockCalled -CommandName Update-Metadata -Scope It -Times 2
        }
    }
}
