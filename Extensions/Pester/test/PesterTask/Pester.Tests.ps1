$taskPath = "$PSScriptRoot\..\..\Task"
$sut = Join-Path -Path $taskPath -ChildPath Pester.ps1 -Resolve

Describe "Testing Pester Task" {

    Context "Testing Task Input" {

        it "ScriptFolder is Mandatory" {
            (Get-Command $sut).Parameters['ScriptFolder'].Attributes.Mandatory | Should -Be $True
        }
        it "Throws Exception when passed an invalid location for ResultsFile" {
            {&$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\RandomFolder } | Should -Throw
        }
        it "Throws Exception when passed an invalid file type for ResultsFile" {
            Mock -CommandName Write-Host -MockWith {}
            {&$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.invalid} | Should -Throw
        }
        it "ResultsFile is Mandatory" {
            (Get-Command $sut).Parameters['ResultsFile'].Attributes.Mandatory | Should -Be $True
        }
        it "Run32Bit is not Mandatory" {
            (Get-Command $sut).Parameters['Run32Bit'].Attributes.Mandatory | Should -Be $False
        }
        it "additionalModulePath is not Mandatory" {
            (Get-Command $sut).Parameters['additionalModulePath'].Attributes.Mandatory | Should -Be $False
        }
        it "CodeCoverageFolder is not Mandatory" {
            (Get-Command $sut).Parameters['CodeCoverageFolder'].Attributes.Mandatory | Should -Be $False
        }
        it "Tag is not Mandatory" {
            (Get-Command $sut).Parameters['Tag'].Attributes.Mandatory | Should -Be $False
        }
        it "additionalModulePath is not Mandatory" {
            (Get-Command $sut).Parameters['additionalModulePath'].Attributes.Mandatory | Should -Be $False
        }
        it "CodeCoverageFolder is not Mandatory" {
            (Get-Command $sut).Parameters['CodeCoverageFolder'].Attributes.Mandatory | Should -Be $False
        }
        it "Calls Invoke-Pester with multiple Tags specified" {
            mock Invoke-Pester { }
            mock Import-Module { }
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Write-Error { }
            Mock Install-Module { }
            Mock Find-Module { }
            Mock Get-PackageProvider { $True }
            Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}

            . $Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml -Tag 'Infrastructure,Integration'
            $Tag.Length | Should Be 2
            Write-Output -NoEnumerate $Tag | Should -BeOfType [System.Array]
            Write-Output -NoEnumerate $Tag | Should -BeOfType [String[]]
        }
        it "ExcludeTag is not Mandatory" {
            (Get-Command $sut).Parameters['ExcludeTag'].Attributes.Mandatory | Should -Be $False
        }
        it "Calls Invoke-Pester with multiple ExcludeTags specified" {
            mock Invoke-Pester { }
            mock Import-Module { }
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Write-Error { }
            Mock Install-Module { }
            Mock Find-Module { }
            Mock Get-PackageProvider { $True }
            Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}

            . $Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml -ExcludeTag 'Example,Demo'
            $ExcludeTag.Length | Should be 2
            Write-Output -NoEnumerate $ExcludeTag | Should -BeOfType [System.Array]
            Write-Output -NoEnumerate $ExcludeTag | Should -BeOfType [String[]]
        }

        it "Handles CodeCoverageOutputFile being null from VSTS" {
            mock Invoke-Pester { }
            mock Import-Module { }
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Write-Error { }
            Mock Install-Module { }
            Mock Find-Module { }
            Mock Get-PackageProvider { $True }
            Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}

            . $Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\Output.xml -CodeCoverageOutputFile $null
            Assert-MockCalled Invoke-Pester
        }

        it "Throw an error if CodeCoverageOutputFile is not an xml file" {
            {. $Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\Output.xml -CodeCoverageOutputFile TestDrive:\codecoverage.csv} | Should Throw
        }

        it "Should have a ScriptBlock parameter which is not mandatory" {
            (Get-Command $sut).Parameters['ScriptBlock'].Attributes.Mandatory | Should -Be $False
        }
    }

    Context "Testing Task Processing" {
        mock Invoke-Pester { "Tag" } -ParameterFilter {$Tag -and $Tag -eq 'Infrastructure'}
        mock Invoke-Pester { "ExcludeTag" } -ParameterFilter {$ExcludeTag -and $ExcludeTag -eq 'Example'}
        mock Invoke-Pester { "AllTests" }
        mock Import-Module { }
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Write-Error { }
        Mock Install-Module { }
        Mock Find-Module { }
        Mock Get-PackageProvider { $True }
        Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}

        it "Calls Invoke-Pester correctly with ScriptFolder and ResultsFile specified" {
            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml
            Assert-MockCalled Invoke-Pester
        }
        it "Calls Invoke-Pester with Tag specified" {
            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml -Tag 'Infrastructure'
            Assert-MockCalled Invoke-Pester -ParameterFilter {$Tag -and $Tag -eq 'Infrastructure'}
        }
        it "Calls Invoke-Pester with ExcludeTag specified" {
            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml -ExcludeTag 'Example'
            Assert-MockCalled Invoke-Pester -ParameterFilter {$ExcludeTag -and $ExcludeTag -eq 'Example'}
        }
        it "Calls Invoke-Pester with the CodeCoverageOutputFile specified" {
            New-Item -Path TestDrive:\ -Name TestFile1.ps1 | Out-Null
            New-Item -Path TestDrive:\ -Name TestFile2.ps1 | Out-Null
            New-Item -Path TestDrive:\ -Name TestFile3.ps1 | Out-Null

            &$Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\Output.xml -CodeCoverageOutputFile 'TestDrive:\codecoverage.xml'
            Assert-MockCalled Invoke-Pester -ParameterFilter {$CodeCoverageOutputFile -and $CodeCoverageOutputFile -eq 'TestDrive:\codecoverage.xml'}
        }
        it "Should update the `$Env:PSModulePath correctly when additionalModulePath is supplied" {
            &$Sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\Output.xml -additionalModulePath TestDrive:\TestFolder

            $Env:PSModulePath | Should -Match ';{0,1}TestDrive:\\TestFolder;{0,1}'
        }
        it "Should Write-Host the contents of Script parameters as a string version of a hashtable when a hashtable is provided" {
            $Parameters = "@{Path = '$PSScriptRoot\parameters.tests.ps1';Parameters=@{TestValue='SomeValue'}}"
            &$Sut -ScriptFolder $Parameters -ResultsFile TestDrive:\Output.xml

            Assert-MockCalled -CommandName Write-Host -ParameterFilter {
                $Object -eq "Running Pester from using the script parameter [$Parameters] output sent to [TestDrive:\Output.xml]"
            }
        }
    }

    Context "Testing Task Output" {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Import-Module { }
        Mock Install-Module { }
        Mock Write-Error { }
        Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}
        mock Invoke-Pester {
            param ($OutputFile)
            New-Item -Path $OutputFile -ItemType File
        } -ParameterFilter {$ResultsFile -and $ResultsFile -eq 'TestDrive:\output.xml'}

        mock Invoke-Pester {
            New-Item -Path $CodeCoverageOutputFile -ItemType File
        } -ParameterFilter {$CodeCoverageOutputFile -and $CodeCoverageOutputFile -eq 'TestDrive:\codecoverage.xml'}

        mock Invoke-Pester {
            New-Item -Path $CodeCoverageOutputFile -ItemType File
        } -ParameterFilter {$CodeCoverageOutputFile -and $CodeCoverageOutputFile -eq 'TestDrive:\codecoverage2.xml' -and $CodeCoverageFolder}

        mock Invoke-Pester {
            New-Item -Path $CodeCoverageOutputFile -ItemType File
        } -ParameterFilter {$CodeCoverageOutputFile -and $CodeCoverageOutputFile -eq 'TestDrive:\codecoverage3.xml' -and $CodeCoverageFolder}

        mock Invoke-Pester {}
        Mock Find-Module { }
        Mock Get-PackageProvider { $True }

        it "Creates the output xml file correctly" {
            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml
            Test-Path -Path TestDrive:\Output.xml | Should -Be $True
        }
        it "Throws an error when pester tests fail" {
            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output2.xml
            Assert-MockCalled -CommandName Write-Error
        }

        it "Creates the CodeCoverage output file correctly" {
            New-Item -Path TestDrive:\ -Name TestFile1.ps1 | Out-Null
            New-Item -Path TestDrive:\ -Name TestFile2.ps1 | Out-Null
            New-Item -Path TestDrive:\ -Name TestFile3.ps1 | Out-Null

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml -CodeCoverageOutputFile 'TestDrive:\codecoverage.xml'
            Test-Path -Path TestDrive:\codecoverage.xml | Should -Be $True
        }

        it "Creates the CodeCoverage output file when code coverage folder is not specified" {
            New-Item -Path TestDrive:\ -Name Tests -ItemType Directory | Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile1.ps1 | Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile2.ps1 | Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile3.ps1 | Out-Null
            New-Item -Path TestDrive:\ -Name Source -ItemType Directory | Out-Null
            New-Item -Path TestDrive:\Source -Name Code.ps1 | Out-Null

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output2.xml -CodeCoverageOutputFile 'TestDrive:\codecoverage2.xml'
            Test-Path -Path TestDrive:\codecoverage.xml | Should -Be $True

            Assert-MockCalled -CommandName Invoke-Pester -ParameterFilter {$CodeCoverage -and $CodeCoverage -contains "$((Get-Item 'TestDrive:\').FullName)Source\Code.ps1"}
        }

        it "Creates the CodeCoverage output file for the specified files" {
            New-Item -Path TestDrive:\ -Name Tests -ItemType Directory -Force| Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile1.ps1 -Force | Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile2.ps1 -Force | Out-Null
            New-Item -Path TestDrive:\Tests -Name TestFile3.ps1 -Force | Out-Null
            New-Item -Path TestDrive:\ -Name Source -ItemType Directory -Force | Out-Null
            New-Item -Path TestDrive:\Source -Name Code.ps1 -Force | Out-Null

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output2.xml -CodeCoverageOutputFile 'TestDrive:\codecoverage3.xml' -CodeCoverageFolder 'TestDrive:\Source'
            Test-Path -Path TestDrive:\codecoverage.xml | Should -Be $True

            Assert-MockCalled -CommandName Invoke-Pester -ParameterFilter {$CodeCoverage -and $CodeCoverage -eq "$((Get-Item 'TestDrive:\').FullName)Source\Code.ps1" -and $CodeCoverage -notlike "$((Get-Item 'TestDrive:\').FullName)Tests\*.ps1"}
        }

    }

    Context "Testing Pester Module Version Loading" {

        mock Invoke-Pester { }
        mock Import-Module { }
        Mock Install-Module { $true }
        Mock Write-host { }
        Mock Write-Warning { }
        Mock Get-PSRepository {[PSCustomObject]@{Name = 'PSGallery'}}
        Mock Write-Error { }
        Mock Get-Command { [PsCustomObject]@{Parameters=@{SkipPublisherCheck='SomeValue'}}} -ParameterFilter {$Name -eq 'Install-Module'}
        Mock Get-Command { [PsCustomObject]@{Parameters=@{AllowPrerelease='SomeValue'}}} -ParameterFilter {$Name -eq 'Find-Module'}

        it "Installs the latest version of Pester when on PS5+ and PowerShellGet is available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path.EndsWith("\4.6.0") }
            Mock Get-ChildItem  { return $true }
            Mock Find-Module { [PsCustomObject]@{Version=[version]::new(9,9,9);Repository='PSGallery'}}
            Mock Get-PackageProvider { $True }

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml

            Assert-MockCalled  Install-Module
            Assert-MockCalled Invoke-Pester
        }
        it "Installs the latest version of Pester from PSGallery when multiple repositories are available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path.EndsWith("\4.6.0") }
            Mock Get-ChildItem  { return $true }
            Mock Find-Module { @(
                    [PsCustomObject]@{Version=[version]::new(4,3,0);Repository='OtherRepository'}
                    [PsCustomObject]@{Version=[version]::new(9,9,9);Repository='PSGallery'}
                )
            }
            Mock Get-PackageProvider { $True }

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml

            Assert-MockCalled Install-Module -Scope It -ParameterFilter {$Repository -eq 'PSGallery'}
            Assert-MockCalled Invoke-Pester
        }
        it "Installs the required version of NuGet provider when PowerShellGet is available and NuGet isn't already installed" {
            Mock Test-Path { return $true } -ParameterFilter { $Path.EndsWith("\4.6.0") }
            Mock Get-ChildItem  { return $true }
            Mock Find-Module { [PsCustomObject]@{Version=[version]::new(9,9,9);Repository='PSGallery'}}
            Mock Get-PackageProvider { throw }
            Mock Install-PackageProvider {}

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml

            Assert-MockCalled Install-PackageProvider
            Assert-MockCalled Install-Module
            Assert-MockCalled Invoke-Pester
        }

        it "Should not install a new version of Pester when the latest is already installed" {
            Mock Test-Path { return $true } -ParameterFilter { $Path.EndsWith("\4.6.0") }
            Mock Get-ChildItem  { return $true }
            Mock Find-Module { [PsCustomObject]@{Version=(Get-Module Pester).Version;Repository='PSGallery'}}
            Mock Get-PackageProvider { $True }

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml

            Assert-MockCalled Install-Module -Times 0 -Scope It
            Assert-MockCalled Invoke-Pester
        }

        it "Should not Install the latest version of Pester when on PowerShellGet is available but SkipPublisherCheck is not available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path.EndsWith("\4.6.0") }
            Mock Get-ChildItem  { return $true }
            Mock Find-Module { [PsCustomObject]@{Version=[version]::new(9,9,9);Repository='PSGallery'}}
            Mock Get-PackageProvider { $True }
            Mock Get-Command { [PsCustomObject]@{Parameters=@{OtherProperty='SomeValue'}} } -ParameterFilter {$Name -eq 'Install-Module'}

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml

            Assert-MockCalled Install-Module -Times 0 -Scope It
            Assert-MockCalled Import-Module -Times 1 -ParameterFilter {$Name -like '*\4.6.0\Pester.psd1'}
            Assert-MockCalled Invoke-Pester
            Assert-MockCalled Write-Warning -Times 0 -ParameterFilter {$Message -eq "Code coverage output not supported on Pester versions before 4.0.4."}
        }
        <#it "Loads Pester version that ships with task when not on PS5+ or PowerShellGet is unavailable" {
            mock Invoke-Pester { }
            mock Import-Module { }
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Write-Error { }
            mock Get-Module { }

            &$sut -ScriptFolder TestDrive:\ -ResultsFile TestDrive:\output.xml
            Assert-MockCalled  Import-Module -ParameterFilter { $Name -eq "$pwd\4.6.0\Pester.psd1" }
            Assert-MockCalled Invoke-Pester
        }#>
    }

}
