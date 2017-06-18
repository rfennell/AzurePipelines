$sut = "$PSScriptRoot\..\..\..\..\extensions\versioning\VersionNuspecTask\ApplyVersionToNuspec.ps1" 

Describe 'Testing Nuspec Versioning Task' {

    Mock -CommandName Write-Verbose -MockWith {}
    Mock -CommandName Write-Warning -MockWith {}
    Mock -CommandName Write-host -MockWith {}

    Context 'Testing input' {
        it 'Should have Path as a mandatory parameter' {
            (Get-Command $sut).Parameters['Path'].Attributes.Mandatory | Should Be $True
        }

        It 'Should throw is given an invalid Path' {
            {&$Sut -Path TestDrive:\Some\Files\Here -VersionNumber '1.2.3.4'} | Should Throw
        }

        It 'Should have version number as a mandartory parameter' {
            (Get-Command $sut).Parameters['VersionNumber'].Attributes.Mandatory | Should Be $True
        }

        It 'Should throw if given an empty or null version regex' {
            {&$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4' -VersionRegex ''} | Should Throw
            {&$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4' -VersionRegex $null} | Should Throw
        }
    }

    Context 'Testing processing' {
        $XmlExample = @"
            <package>
            <metadata>
            <version>5.6.7.8</version>
            </metadata>
            </package>
"@
        New-Item -Path TestDrive:\ -Name Example.nuspec -ItemType File -Value $XmlExample
        New-Item -Path TestDrive:\ -Name SubFolder -ItemType Directory
        New-Item -Path TestDrive:\SubFolder -Name OtherFile.nuspec -ItemType File -Value $XmlExample

        it 'should attempt to edit all files found' {
            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4' -VersionRegex '\d.\d.\d.\d'

            (Get-Content -Path TestDrive:\Example.nuspec -raw) -ne $XmlExample | Should be $true
            (Get-Content -Path TestDrive:\Subfolder\Otherfile.nuspec -raw) -ne $XmlExample | Should be $true
        }

        it 'should write a warning if no files found' {
            Mock -CommandName Get-ChildItem -MockWith {}
            &$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4' -VersionRegex '\d.\d.\d.\d'

            Assert-MockCalled -CommandName Write-Warning -Times 1 -Exactly -Scope It
        }

        it 'should call all mocks' {
            Mock -CommandName Get-ChildItem -MockWith {@(1,2)}
            Mock -CommandName Get-Content -MockWith {$XmlExample}
            
            {&$Sut -Path TestDrive:\ -VersionNumber '1.2.3.4'} | Should Not Throw
            Assert-MockCalled -CommandName Get-ChildItem -Times 1
            Assert-MockCalled -CommandName Get-Content -Times 2
        }

    }
}