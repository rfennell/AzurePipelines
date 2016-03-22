Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write nunit test results (Legacy)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]::FromSeconds(2.5)
            $TestResults.AddTestResult("Failed testcase","Failed",$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'

            $description = $null
            if ($xmlTestResult.PSObject.Properties['description'])
            {
                $description = $xmlTestResult.description
            }

            $xmlTestResult.type    | Should Be "Powershell"
            $xmlTestResult.name    | Should Be "Mocked Describe"
            $description           | Should BeNullOrEmpty
            $xmlTestResult.result  | Should Be "Success"
            $xmlTestResult.success | Should Be "True"
            $xmlTestResult.time    | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]

            $description = $null
            if ($xmlTestSuite1.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite1.description
            }

            $xmlTestSuite1.name    | Should Be "Describe #1"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite1.result  | Should Be "Success"
            $xmlTestSuite1.success | Should Be "True"
            $xmlTestSuite1.time    | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $description = $null
            if ($xmlTestSuite2.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite2.description
            }

            $xmlTestSuite2.name    | Should Be "Describe #2"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite2.result  | Should Be "Failure"
            $xmlTestSuite2.success | Should Be "False"
            $xmlTestSuite2.time    | Should Be 2.0
        }

        it "should write parent results in tree correctly" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Failed')
            $TestResults.AddTestResult("Failed","Failed")
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Skipped')
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Pending')
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Passed')
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name     | Should Be "Failed"
            $xmlTestSuite1.result   | Should Be "Failure"
            $xmlTestSuite1.success  | Should Be "False"

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name     | Should Be "Skipped"
            $xmlTestSuite2.result   | Should Be "Skipped"
            $xmlTestSuite2.success  | Should Be "True"

            $xmlTestSuite3 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[2]
            $xmlTestSuite3.name     | Should Be "Pending"
            $xmlTestSuite3.result   | Should Be "Inconclusive"
            $xmlTestSuite3.success  | Should Be "True"

            $xmlTestSuite4 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[3]
            $xmlTestSuite4.name     | Should Be "Passed"
            $xmlTestSuite4.result   | Should Be "Success"
            $xmlTestSuite4.success  | Should Be "True"

        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (New Legacy)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{ Parameter = 'One' }
            )

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                @{ Parameter = 'Two' }

            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $description = $null
                if ($xmlTestSuite.PSObject.Properties['description'])
                {
                    $description = $xmlTestSuite.description
                }

                $xmlTestSuite.name    | Should Be 'Parameterized Testcase <A>'
                $description          | Should BeNullOrEmpty
                $xmlTestSuite.type    | Should Be 'ParameterizedTest'
                $xmlTestSuite.result  | Should Be 'Failure'
                $xmlTestSuite.success | Should Be 'False'
                $xmlTestSuite.time    | Should Be '2'

                foreach ($testCase in $xmlTestSuite.results.'test-case')
                {
                    $testCase.Name | Should Match '^Parameterized Testcase (One|<A>)$'
                    $testCase.time | Should Be 1
                }
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Write nunit test results (Newer format)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Mocked Describe.Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]25000000 #2.5 seconds
            $TestResults.AddTestResult("Failed testcase",'Failed',$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Mocked Describe.Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type            | Should Be "TestFixture"
            $xmlTestResult.name            | Should Be "Mocked Describe"
            $xmlTestResult.description     | Should Be "Mocked Describe"
            $xmlTestResult.result          | Should Be "Success"
            $xmlTestResult.success         | Should Be "True"
            $xmlTestResult.time            | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name        | Should Be "Describe #1"
            $xmlTestSuite1.description | Should Be "Describe #1"
            $xmlTestSuite1.result      | Should Be "Success"
            $xmlTestSuite1.success     | Should Be "True"
            $xmlTestSuite1.time        | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name        | Should Be "Describe #2"
            $xmlTestSuite2.description | Should Be "Describe #2"
            $xmlTestSuite2.result      | Should Be "Failure"
            $xmlTestSuite2.success     | Should Be "False"
            $xmlTestSuite2.time        | Should Be 2.0
        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (Newer format)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{Parameter = 'One'}
            )

            $parameters = New-Object System.Collections.Specialized.OrderedDictionary
            $parameters.Add('StringParameter', 'Two')
            $parameters.Add('NullParameter', $null)
            $parameters.Add('NumberParameter', -42.67)

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                $parameters
            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $xmlTestSuite.name        | Should Be 'Mocked Describe.Parameterized Testcase <A>'
                $xmlTestSuite.description | Should Be 'Parameterized Testcase <A>'
                $xmlTestSuite.type        | Should Be 'ParameterizedTest'
                $xmlTestSuite.result      | Should Be 'Failure'
                $xmlTestSuite.success     | Should Be 'False'
                $xmlTestSuite.time        | Should Be '2'

                $testCase1 = $xmlTestSuite.results.'test-case'[0]
                $testCase2 = $xmlTestSuite.results.'test-case'[1]

                $testCase1.Name | Should Be 'Mocked Describe.Parameterized Testcase One'
                $testCase1.Time | Should Be 1

                $testCase2.Name | Should Be 'Mocked Describe.Parameterized Testcase <A>("Two",null,-42.67)'
                $testCase2.Time | Should Be 1
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Get-TestTime" {
        function Using-Culture {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [ScriptBlock]$ScriptBlock,
                [System.Globalization.CultureInfo]$Culture='en-US'
            )

            $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
            }
        }

        It "output is culture agnostic" {
            #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
            #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

            #using the string formatter here to know how the string will be output to screen
            $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
            $Result | Should Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should Be 0.1235
        }
    }

    Describe "GetFullPath" {
        It "Resolves non existing path correctly" {
            pushd TestDrive:\
            $p = GetFullPath notexistingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            pushd TestDrive:\
            New-Item -ItemType File -Name existingfile.txt
            $p = GetFullPath existingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive existingfile.txt)
        }

        It "Resolves full path correctly" {
            GetFullPath C:\Windows\System32\notepad.exe | Should Be C:\Windows\System32\notepad.exe
        }
    }
}

# SIG # Begin signature block
# MIIatwYJKoZIhvcNAQcCoIIaqDCCGqQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJPJXJmbtuNrFGJeezQ3Y9Erp
# qeugghV6MIIEuzCCA6OgAwIBAgITMwAAAF3JyvZpIzdoUAAAAAAAXTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTQwNTIzMTcxMzE3
# WhcNMTUwODIzMTcxMzE3WjCBqzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# DTALBgNVBAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjo3RDJFLTM3
# ODItQjBGNzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKu6ei+vVB909A1zsuALhVjs
# q6u/RwD+jTcx8hyTPqa6zhvmUUBo1IAY11hjXQM3NvuDWHDexDM2sF8Hf33991ir
# WpduRc648Rs9Us+lPQVDm6CxNHLT7/MxvC5ojio1Cy50sO/kK1VyZZWPZ/SjyO8D
# EafcCzyhbA7/YYxCkuRWw5Gxj/au18Hj6KgZAaIXYL9DmHoqWmo0yJINP+BcHbd/
# sFodvcxsahFDHgINW0LpbUtjCzn7UqPseibSojBHY9L46hXYaS6eJulOTxyz0uJg
# Jj9uXZIUkF40bXgEfFJRmwsBdutBAFlTztuN1kmFbII7fsTph0ayOTzxXthvcv8C
# AwEAAaOCAQkwggEFMB0GA1UdDgQWBBTXVOYV2dNdyiTVARjweGSZe2hMMzAfBgNV
# HSMEGDAWgBQjNPjZUkZwCu1A+3b7syuwwzWzDzBUBgNVHR8ETTBLMEmgR6BFhkNo
# dHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNyb3Nv
# ZnRUaW1lU3RhbXBQQ0EuY3JsMFgGCCsGAQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRUaW1l
# U3RhbXBQQ0EuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBBQUA
# A4IBAQCJMKxtI1M8/5xen1dwDBzeF903pNyVsaYkzAfuqYXRHNXZm0k3IZ8xPmmu
# v7UwG+ekLFDrwVCISqq17KiyCUCwau9zVEKtnimFVG2zD/GYfuP4wDAbTNKGKfCi
# 5V6bN41mnei8W2+6lcb20i5BNfnHvgyK5iZEdmgcnKQW7iJVpNZXK/gNgSAsoQ+a
# jvzHlcVeh4RB4tJvnM/QZSMW29B9hNAGFhKlZy17hYk+RZPYzSaZ+7Yq4VJCmhCX
# HzTakcGshvOSRG1Qu4mykew1qEj2weHE/sZlfUHv7W3KkeTmsNnlWFy0u5romkYc
# Zt0eS0SYyfRKWBF/kMshN4hDyN71MIIE7DCCA9SgAwIBAgITMwAAAMps1TISNcTh
# VQABAAAAyjANBgkqhkiG9w0BAQUFADB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBD
# QTAeFw0xNDA0MjIxNzM5MDBaFw0xNTA3MjIxNzM5MDBaMIGDMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQD
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCWcV3tBkb6hMudW7dGx7DhtBE5A62xFXNgnOuntm4aPD//ZeM08aal
# IV5WmWxY5JKhClzC09xSLwxlmiBhQFMxnGyPIX26+f4TUFJglTpbuVildGFBqZTg
# rSZOTKGXcEknXnxnyk8ecYRGvB1LtuIPxcYnyQfmegqlFwAZTHBFOC2BtFCqxWfR
# +nm8xcyhcpv0JTSY+FTfEjk4Ei+ka6Wafsdi0dzP7T00+LnfNTC67HkyqeGprFVN
# TH9MVsMTC3bxB/nMR6z7iNVSpR4o+j0tz8+EmIZxZRHPhckJRIbhb+ex/KxARKWp
# iyM/gkmd1ZZZUBNZGHP/QwytK9R/MEBnAgMBAAGjggFgMIIBXDATBgNVHSUEDDAK
# BggrBgEFBQcDAzAdBgNVHQ4EFgQUH17iXVCNVoa+SjzPBOinh7XLv4MwUQYDVR0R
# BEowSKRGMEQxDTALBgNVBAsTBE1PUFIxMzAxBgNVBAUTKjMxNTk1K2I0MjE4ZjEz
# LTZmY2EtNDkwZi05YzQ3LTNmYzU1N2RmYzQ0MDAfBgNVHSMEGDAWgBTLEejK0rQW
# WAHJNy4zFha5TJoKHzBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNDb2RTaWdQQ0FfMDgtMzEtMjAx
# MC5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY0NvZFNpZ1BDQV8wOC0zMS0yMDEwLmNy
# dDANBgkqhkiG9w0BAQUFAAOCAQEAd1zr15E9zb17g9mFqbBDnXN8F8kP7Tbbx7Us
# G177VAU6g3FAgQmit3EmXtZ9tmw7yapfXQMYKh0nfgfpxWUftc8Nt1THKDhaiOd7
# wRm2VjK64szLk9uvbg9dRPXUsO8b1U7Brw7vIJvy4f4nXejF/2H2GdIoCiKd381w
# gp4YctgjzHosQ+7/6sDg5h2qnpczAFJvB7jTiGzepAY1p8JThmURdwmPNVm52Iao
# AP74MX0s9IwFncDB1XdybOlNWSaD8cKyiFeTNQB8UCu8Wfz+HCk4gtPeUpdFKRhO
# lludul8bo/EnUOoHlehtNA04V9w3KDWVOjic1O1qhV0OIhFeezCCBbwwggOkoAMC
# AQICCmEzJhoAAAAAADEwDQYJKoZIhvcNAQEFBQAwXzETMBEGCgmSJomT8ixkARkW
# A2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9z
# b2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTEwMDgzMTIyMTkzMloX
# DTIwMDgzMTIyMjkzMloweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCycllcGTBkvx2aYCAgQpl2U2w+G9Zv
# zMvx6mv+lxYQ4N86dIMaty+gMuz/3sJCTiPVcgDbNVcKicquIEn08GisTUuNpb15
# S3GbRwfa/SXfnXWIz6pzRH/XgdvzvfI2pMlcRdyvrT3gKGiXGqelcnNW8ReU5P01
# lHKg1nZfHndFg4U4FtBzWwW6Z1KNpbJpL9oZC/6SdCnidi9U3RQwWfjSjWL9y8lf
# RjFQuScT5EAwz3IpECgixzdOPaAyPZDNoTgGhVxOVoIoKgUyt0vXT2Pn0i1i8UU9
# 56wIAPZGoZ7RW4wmU+h6qkryRs83PDietHdcpReejcsRj1Y8wawJXwPTAgMBAAGj
# ggFeMIIBWjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTLEejK0rQWWAHJNy4z
# Fha5TJoKHzALBgNVHQ8EBAMCAYYwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEE
# AYI3FQIEFgQU/dExTtMmipXhmGA7qDFvpjy82C0wGQYJKwYBBAGCNxQCBAweCgBT
# AHUAYgBDAEEwHwYDVR0jBBgwFoAUDqyCYEBWJ5flJRP8KuEKU5VZ5KQwUAYDVR0f
# BEkwRzBFoEOgQYY/aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUFBwEBBEgwRjBEBggr
# BgEFBQcwAoY4aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNy
# b3NvZnRSb290Q2VydC5jcnQwDQYJKoZIhvcNAQEFBQADggIBAFk5Pn8mRq/rb0Cx
# MrVq6w4vbqhJ9+tfde1MOy3XQ60L/svpLTGjI8x8UJiAIV2sPS9MuqKoVpzjcLu4
# tPh5tUly9z7qQX/K4QwXaculnCAt+gtQxFbNLeNK0rxw56gNogOlVuC4iktX8pVC
# nPHz7+7jhh80PLhWmvBTI4UqpIIck+KUBx3y4k74jKHK6BOlkU7IG9KPcpUqcW2b
# Gvgc8FPWZ8wi/1wdzaKMvSeyeWNWRKJRzfnpo1hW3ZsCRUQvX/TartSCMm78pJUT
# 5Otp56miLL7IKxAOZY6Z2/Wi+hImCWU4lPF6H0q70eFW6NB4lhhcyTUWX92THUmO
# Lb6tNEQc7hAVGgBd3TVbIc6YxwnuhQ6MT20OE049fClInHLR82zKwexwo1eSV32U
# jaAbSANa98+jZwp0pTbtLS8XyOZyNxL0b7E8Z4L5UrKNMxZlHg6K3RDeZPRvzkbU
# 0xfpecQEtNP7LN8fip6sCvsTJ0Ct5PnhqX9GuwdgR2VgQE6wQuxO7bN2edgKNAlt
# HIAxH+IOVN3lofvlRxCtZJj/UBYufL8FIXrilUEnacOTj5XJjdibIa4NXJzwoq6G
# aIMMai27dmsAHZat8hZ79haDJLmIz2qoRzEvmtzjcT3XAH5iR9HOiMm4GPoOco3B
# oz2vAkBq/2mbluIQqBC0N1AI1sM9MIIGBzCCA++gAwIBAgIKYRZoNAAAAAAAHDAN
# BgkqhkiG9w0BAQUFADBfMRMwEQYKCZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPy
# LGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZp
# Y2F0ZSBBdXRob3JpdHkwHhcNMDcwNDAzMTI1MzA5WhcNMjEwNDAzMTMwMzA5WjB3
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhN
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCfoWyx39tIkip8ay4Z4b3i48WZUSNQrc7dGE4kD+7Rp9FMrXQwIBHr
# B9VUlRVJlBtCkq6YXDAm2gBr6Hu97IkHD/cOBJjwicwfyzMkh53y9GccLPx754gd
# 6udOo6HBI1PKjfpFzwnQXq/QsEIEovmmbJNn1yjcRlOwhtDlKEYuJ6yGT1VSDOQD
# LPtqkJAwbofzWTCd+n7Wl7PoIZd++NIT8wi3U21StEWQn0gASkdmEScpZqiX5NMG
# gUqi+YSnEUcUCYKfhO1VeP4Bmh1QCIUAEDBG7bfeI0a7xC1Un68eeEExd8yb3zuD
# k6FhArUdDbH895uyAc4iS1T/+QXDwiALAgMBAAGjggGrMIIBpzAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBQjNPjZUkZwCu1A+3b7syuwwzWzDzALBgNVHQ8EBAMC
# AYYwEAYJKwYBBAGCNxUBBAMCAQAwgZgGA1UdIwSBkDCBjYAUDqyCYEBWJ5flJRP8
# KuEKU5VZ5KShY6RhMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAXBgoJkiaJk/Is
# ZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eYIQea0WoUqgpa1Mc1j0BxMuZTBQBgNVHR8ESTBHMEWgQ6BB
# hj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9taWNy
# b3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjho
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jvc29mdFJvb3RD
# ZXJ0LmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQUFAAOCAgEA
# EJeKw1wDRDbd6bStd9vOeVFNAbEudHFbbQwTq86+e4+4LtQSooxtYrhXAstOIBNQ
# md16QOJXu69YmhzhHQGGrLt48ovQ7DsB7uK+jwoFyI1I4vBTFd1Pq5Lk541q1YDB
# 5pTyBi+FA+mRKiQicPv2/OR4mS4N9wficLwYTp2OawpylbihOZxnLcVRDupiXD8W
# mIsgP+IHGjL5zDFKdjE9K3ILyOpwPf+FChPfwgphjvDXuBfrTot/xTUrXqO/67x9
# C0J71FNyIe4wyrt4ZVxbARcKFA7S2hSY9Ty5ZlizLS/n+YWGzFFW6J1wlGysOUzU
# 9nm/qhh6YinvopspNAZ3GmLJPR5tH4LwC8csu89Ds+X57H2146SodDW4TsVxIxIm
# dgs8UoxxWkZDFLyzs7BNZ8ifQv+AeSGAnhUwZuhCEl4ayJ4iIdBD6Svpu/RIzCzU
# 2DKATCYqSCRfWupW76bemZ3KOm+9gSd0BhHudiG/m4LBJ1S2sWo9iaF2YbRuoROm
# v6pH8BJv/YoybLL+31HIjCPJZr2dHYcSZAI9La9Zj7jkIeW1sMpjtHhUBdRBLlCs
# lLCleKuzoJZ1GtmShxN1Ii8yqAhuoFuMJb+g74TKIdbrHk/Jmu5J4PcBZW+JC33I
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggSnMIIEowIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIHAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQZYusjKq1LT/TM
# +ewhsHR3qYjh1zBgBgorBgEEAYI3AgEMMVIwUKAmgCQAVwBpAG4AZABvAHcAcwAg
# AFAAbwB3AGUAcgBTAGgAZQBsAGyhJoAkaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3Bvd2Vyc2hlbGwgMA0GCSqGSIb3DQEBAQUABIIBABbbjheqIV97ppDGhCqcsi2h
# ux5tgef2UtvmGN/GQK3JoiWh1PtHnYxXsojQFRYLeRSAIPt3SmyEbvdm7juXobnR
# dEEcQFp9/W7p1aoPMspLANSNWpnQoCjaxrxO4xlRDMkO25UQZe8pX5SzIB52AVSq
# hH5z8ZXAzZtX/AqLwdWSXgu7L0qprO0CpthaqPVudU18OPaLnV+u4zMXTVn6r/uh
# BpcJ2bCfV+iJbG4SSyzFU2P7nQfFNcA3hiQCTMkWlZkBER4y/O0aBrlWv6MlDgtg
# mU2/hm7tm0biwKomU2fmt5HefDyKGDFL8nUR20BoCDjSlhtgMO27LeFYaUAZRZCh
# ggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBAhMzAAAAXcnK9mkjN2hQAAAAAABdMAkGBSsOAwIaBQCgXTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTAzMDUyMzU5
# MDhaMCMGCSqGSIb3DQEJBDEWBBQwOF39IK5Xldy9W05OeCaR9mCBsjANBgkqhkiG
# 9w0BAQUFAASCAQBvXkqq3R5xrXFaSwgJTKhBaj/H6qWfyceW3SpeCke9LnDE//Gt
# zWSLNAKCJTQ40qvzdPCorwieAg6A+GRKbrFSLTC2YFtQb1ol7ewmm/nC5H+HdDXl
# f2xurvKsHuREJF9j2bcnsFQzHYsALU4RE35IjeR9BdSQbrRq3yGdzw7nvwlO94ZT
# xeAyRQsNetF2SxGC7nvV4SlnSxIYs9jU0LC467dkhQxso2bAPBR/VpuS1E/NtfBN
# pGtk+FWuzWkbraiwegunxhlceIU7q5JogxCx1nCZTrSRkhWgDUx8dXBmG8jfaqKp
# AJTTYGLZj7mGwgCiW55/O+Ipv/Nty3cZVDA3
# SIG # End signature block
