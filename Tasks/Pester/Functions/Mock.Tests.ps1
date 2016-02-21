Set-StrictMode -Version Latest

function FunctionUnderTest
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $param1
    )

    return "I am a real world test"
}

function FunctionUnderTestWithoutParams([string]$param1) {
    return "I am a real world test with no params"
}

filter FilterUnderTest { $_ }

function CommonParamFunction (
    [string] ${Uncommon},
    [switch]
    ${Verbose},
    [switch]
    ${Debug},
    [System.Management.Automation.ActionPreference]
    ${ErrorAction},
    [System.Management.Automation.ActionPreference]
    ${WarningAction},
    [System.String]
    ${ErrorVariable},
    [System.String]
    ${WarningVariable},
    [System.String]
    ${OutVariable},
    [System.Int32]
    ${OutBuffer} ){
    return "Please strip me of my common parameters. They are far too common."
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest { return "I am the mock test that was passed $param1"}

    $result = FunctionUnderTest "boundArg"

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed | Should Be $true
    }

    It "Should Invoke the mocked script" {
        $result | Should Be "I am the mock test that was passed boundArg"
    }
}

Describe "When the caller mocks a command Pester uses internally" {
    Mock Write-Host { }

    Context "Context run when Write-Host is mocked" {
        It "does not make extra calls to the mocked command" {
            Write-Host 'Some String'
            Assert-MockCalled 'Write-Host' -Exactly 1
        }

        It "retains the correct mock count after the first test completes" {
            Assert-MockCalled 'Write-Host' -Exactly 1
        }
    }
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Get-Process"
    }

    It 'Should not resolve $args to the parent scope' {
        { $args = 'From', 'Parent', 'Scope'; Get-Process SomeName } | Should Not Throw
    }
}

Describe 'When calling Mock on an alias' {
    $originalPath = $env:path

    try
    {
        # Our TeamCity server has a dir.exe on the system path, and PowerShell v2 apparently finds that instead of the PowerShell alias first.
        # This annoying bit of code makes sure our test works as intended even when this is the case.

        $dirExe = Get-Command dir -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $dirExe)
        {
            foreach ($app in $dirExe)
            {
                $parent = (Split-Path $app.Path -Parent).TrimEnd('\')
                $pattern = "^$([regex]::Escape($parent))\\?"

                $env:path = $env:path -split ';' -notmatch $pattern -join ';'
            }
        }

        Mock dir {return 'I am not dir'}

        $result = dir

        It 'Should Invoke the mocked script' {
            $result | Should Be 'I am not dir'
        }
    }
    finally
    {
        $env:path = $originalPath
    }
}

Describe 'When calling Mock on an alias that refers to a function Pester can''t see' {
    It 'Mocks the aliased command successfully' {
        # This function is defined in a non-global scope; code inside the Pester module can't see it directly.
        function orig {'orig'}
        New-Alias 'ali' orig

        ali | Should Be 'orig'

        { mock ali {'mck'} } | Should Not Throw

        ali | Should Be 'mck'
    }
}

Describe 'When calling Mock on a filter' {
    Mock FilterUnderTest {return 'I am not FilterUnderTest'}

    $result = 'Yes I am' | FilterUnderTest

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not FilterUnderTest'
    }
}

Describe 'When calling Mock on an external script' {
    $ps1File = New-Item 'TestDrive:\tempExternalScript.ps1' -ItemType File -Force
    $ps1File | Set-Content -Value "'I am tempExternalScript.ps1'"

    Mock 'TestDrive:\tempExternalScript.ps1' {return 'I am not tempExternalScript.ps1'}

    <#
        # Invoking the script using its absolute path is not supported

        $result = TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using the command-invocation operator (&)' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }
    #>

    Push-Location TestDrive:\

    try
    {
        $result = tempExternalScript.ps1
        It 'Should Invoke the mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & tempExternalScript.ps1
        It 'Should Invoke the mocked script using the command-invocation operator' {
            #the command invocation operator is (&). Moved this to comment because it breaks the contionuous builds.
            #there is issue for this on GH

            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . tempExternalScript.ps1
        It 'Should Invoke the mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        <#
            # Invoking the script using only its relative path is not supported

            $result = .\tempExternalScript.ps1
            It 'Should Invoke the relative-path-qualified mocked script' {
                $result | Should Be 'I am not tempExternalScript.ps1'
            }
        #>

    }
    finally
    {
        Pop-Location
    }

    Remove-Item $ps1File -Force -ErrorAction SilentlyContinue
}

Describe 'When calling Mock on an application command' {
    Mock schtasks.exe {return 'I am not schtasks.exe'}

    $result = schtasks.exe

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not schtasks.exe'
    }
}

Describe "When calling Mock in the Describe block" {
    Mock Out-File {return "I am not Out-File"}

    It "Should mock Out-File successfully" {
        $outfile = "test" | Out-File "TestDrive:\testfile.txt"
        $outfile | Should Be "I am not Out-File"
    }
}

Describe "When calling Mock on existing cmdlet to handle pipelined input" {
    Mock Get-ChildItem {
        if($_ -eq 'a'){
            return "AA"
        }
        if($_ -eq 'b'){
            return "BB"
        }
    }

    $result = ''
    "a", "b" | Get-ChildItem | % { $result += $_ }

    It "Should process the pipeline in the mocked script" {
        $result | Should Be "AABB"
    }
}

Describe "When calling Mock on existing cmdlet with Common params" {
    Mock CommonParamFunction

    $result=[string](Get-Content function:\CommonParamFunction)

    It "Should strip verbose" {
        $result.contains("`${Verbose}") | Should Be $false
    }
    It "Should strip Debug" {
        $result.contains("`${Debug}") | Should Be $false
    }
    It "Should strip ErrorAction" {
        $result.contains("`${ErrorAction}") | Should Be $false
    }
    It "Should strip WarningAction" {
        $result.contains("`${WarningAction}") | Should Be $false
    }
    It "Should strip ErrorVariable" {
        $result.contains("`${ErrorVariable}") | Should Be $false
    }
    It "Should strip WarningVariable" {
        $result.contains("`${WarningVariable}") | Should Be $false
    }
    It "Should strip OutVariable" {
        $result.contains("`${OutVariable}") | Should Be $false
    }
    It "Should strip OutBuffer" {
        $result.contains("`${OutBuffer}") | Should Be $false
    }
    It "Should not strip an Uncommon param" {
        $result.contains("`${Uncommon}") | Should Be $true
    }
}

Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message | Should Be "Could not find command NotFunctionUnderTest"
    }
}

Describe 'When calling Mock, StrictMode is enabled, and variables are used in the ParameterFilter' {
    Set-StrictMode -Version Latest

    $result = $null
    $testValue = 'test'

    try
    {
        Mock FunctionUnderTest { 'I am the mock' } -ParameterFilter { $param1 -eq $testValue }
    }
    catch
    {
        $result = $_
    }

    It 'Does not throw an error when testing the parameter filter' {
        $result | Should Be $null
    }

    It 'Calls the mock properly' {
        FunctionUnderTest $testValue | Should Be 'I am the mock'
    }

    It 'Properly asserts the mock was called when there is a variable in the parameter filter' {
        Assert-MockCalled FunctionUnderTest -Exactly 1 -ParameterFilter { $param1 -eq $testValue }
    }
}

Describe "When calling Mock on existing function without matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test"
    }
}

Describe "When calling Mock on existing function with matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe "When calling Mock on existing function without matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "test" -and $args[0] -eq 'notArg0'}

    $result=FunctionUnderTestWithoutParams -param1 "test" "arg0"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test with no params"
    }
}

Describe "When calling Mock on existing function with matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "badTest" -and $args[0] -eq 'arg0'}

    $result=FunctionUnderTestWithoutParams "badTest" "arg0"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe 'When calling Mock on a function that has no parameters' {
    function Test-Function { }
    Mock Test-Function { return $args.Count }

    It 'Sends the $args variable properly with 2+ elements' {
        Test-Function 1 2 3 4 5 | Should Be 5
    }

    It 'Sends the $args variable properly with 1 element' {
        Test-Function 1 | Should Be 1
    }

    It 'Sends the $args variable properly with 0 elements' {
        Test-Function | Should Be 0
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Set-Item {return "I am not Set-Item"}
    Mock Set-Item {return "I am not Set-Item"}

    $result = Set-Item "mypath" -value "value"

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Set-Item"
    }
}

Describe "When calling Mock on More than one command" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    Mock FunctionUnderTest {return "I am the mock test"}

    $result = Invoke-Command {return "yes I am"}
    $result2 = FunctionUnderTest

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am not Invoke-Command"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the mock test"
    }
}

Describe 'When calling Mock on a module-internal function.' {
    New-Module -Name TestModule {
        function InternalFunction { 'I am the internal function' }
        function PublicFunction   { InternalFunction }
        function PublicFunctionThatCallsExternalCommand { Start-Sleep 0 }
        Export-ModuleMember -Function PublicFunction, PublicFunctionThatCallsExternalCommand
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function InternalFunction { 'I am the second module internal function' }
        function InternalFunction2 { 'I am the second module, second function' }
        function PublicFunction   { InternalFunction }
        function PublicFunction2 { InternalFunction2 }
        Export-ModuleMember -Function PublicFunction, PublicFunction2
    } | Import-Module -Force

    It 'Should fail to call the internal module function' {
        { TestModule\InternalFuncTion } | Should Throw
    }

    It 'Should call the actual internal module function from the public function' {
        TestModule\PublicFunction | Should Be 'I am the internal function'
    }

    Context 'Using Mock -ModuleName "ModuleName" "CommandName" syntax' {
        Mock -ModuleName TestModule InternalFunction { 'I am the mock test' }

        It 'Should call the mocked function' {
            TestModule\PublicFunction | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule Start-Sleep { }

        It 'Should mock calls to external functions from inside the module' {
            PublicFunctionThatCallsExternalCommand

            Assert-MockCalled -ModuleName TestModule Start-Sleep -Exactly 1
        }

        Mock -ModuleName TestModule2 InternalFunction -ParameterFilter { $args[0] -eq 'Test' } {
            "I'm the mock who's been passed parameter Test"
        }

        It 'Should only call mocks within the same module' {
            TestModule2\PublicFunction | Should Be 'I am the second module internal function'
        }

        Mock -ModuleName TestModule2 InternalFunction2 {
            InternalFunction 'Test'
        }

        It 'Should call mocks from inside another mock' {
            TestModule2\PublicFunction2 | Should Be "I'm the mock who's been passed parameter Test"
        }
    }

    Remove-Module TestModule -Force
    Remove-Module TestModule2 -Force
}

Describe "When Applying multiple Mocks on a single command" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "two"

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am the first mock test"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1.Length -gt 0 }
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -gt 1 }

    $result = FunctionUnderTest "one"

    It "The last Mock should win" {
        $result | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "three"

    It "The parameterless mock is evaluated last" {
        $result | Should Be "I am the first mock test"
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2 | Should Be "I am the paramless mock test"
    }
}

Describe "When Creating a Verifiable Mock that is not called" {
    Context "In the test script's scope" {
        Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        FunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected FunctionUnderTest to be called with `$param1 -eq `"one`""
        }
    }

    Context "In a module's scope" {
        New-Module -Name TestModule -ScriptBlock {
            function ModuleFunctionUnderTest { return 'I am the function under test in a module' }
        } | Import-Module -Force

        Mock -ModuleName TestModule ModuleFunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        TestModule\ModuleFunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected ModuleFunctionUnderTest in module TestModule to be called with `$param1 -eq `"one`""
        }

        Remove-Module TestModule -Force
    }
}

Describe "When Creating a Verifiable Mock that is called" {
    Mock FunctionUnderTest -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    It "Assert-VerifiableMocks Should not throw" {
        { Assert-VerifiableMocks } | Should Not Throw
    }
}

Describe "When Calling Assert-MockCalled 0 without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest 0
    } Catch {
        $result=$_
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 0 times exactly but was called 1 times"
    }

    It "Should not throw if mock was not called" {
        Assert-MockCalled FunctionUnderTest 0 { $param1 -eq "stupid" }
    }
}

Describe "When Calling Assert-MockCalled with exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest -exactly 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 3 times exactly but was called 2 times"
    }

    It "Should not throw if mock was called the number of times specified" {
        Assert-MockCalled FunctionUnderTest -exactly 2 { $param1 -eq "one" }
    }
}

Describe "When Calling Assert-MockCalled without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called atleast the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called at least 3 times but was called 2 times"
    }

    It "Should not throw if mock was called at least the number of times specified" {
        Assert-MockCalled FunctionUnderTest
    }

    It "Should not throw if mock was called at exactly the number of times specified" {
        Assert-MockCalled FunctionUnderTest 2 { $param1 -eq "one" }
    }
}

Describe "Using Pester Scopes (Describe,Context,It)" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}

    Context "When in the first context" {
        It "should mock Describe scoped paramles mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When in the second context" {
        It "should mock Describe scoped paramles mock again" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock again" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When using mocks in both scopes" {
        Mock FunctionUnderTestWithoutParams {return "I am the other function"}

        It "should mock Describe scoped mock." {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Context scoped mock." {
            FunctionUnderTestWithoutParams | should be "I am the other function"
        }
    }

    Context "When context hides a describe mock" {
        Mock FunctionUnderTest {return "I am the context mock"}
        Mock FunctionUnderTest {return "I am the parameterized context mock"} -parameterFilter {$param1 -eq "one"}

        It "should use the context paramles mock" {
            FunctionUnderTest | should be "I am the context mock"
        }
        It "should use the context parameterized mock" {
            FunctionUnderTest "one" | should be "I am the parameterized context mock"
        }
    }

    Context "When context no longer hides a describe mock" {
        It "should use the describe mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }

        It "should use the describe parameterized mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context 'When someone calls Mock from inside an It block' {
        Mock FunctionUnderTest { return 'I am the context mock' }

        It 'Sets the mock' {
            Mock FunctionUnderTest { return 'I am the It mock' }
        }

        It 'Leaves the mock active in the parent scope' {
            FunctionUnderTest | Should Be 'I am the It mock'
        }
    }
}

Describe 'Testing mock history behavior from each scope' {
    function MockHistoryChecker { }
    Mock MockHistoryChecker { 'I am the describe mock.' }

    Context 'Without overriding the mock in lower scopes' {
        It "Reports that zero calls have been made to in the describe scope" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope Describe
        }

        It 'Calls the describe mock' {
            MockHistoryChecker | Should Be 'I am the describe mock.'
        }

        It "Reports that zero calls have been made in an It block, after a context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope It
        }

        It "Reports one Context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It "Reports one Describe-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'After exiting the previous context' {
        It 'Reports zero context-scoped calls in the new context.' {
            Assert-MockCalled MockHistoryChecker -Exactly 0
        }

        It 'Reports one describe-scoped call from the previous context' {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'While overriding mocks in lower scopes' {
        Mock MockHistoryChecker { 'I am the context mock.' }

        It 'Calls the context mock' {
            MockHistoryChecker | Should Be 'I am the context mock.'
        }

        It 'Reports one context-scoped call' {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It 'Reports two describe-scoped calls, even when one is an override mock in a lower scope' {
            Assert-MockCalled MockHistoryChecker -Exactly 2 -Scope Describe
        }

        It 'Calls an It-scoped mock' {
            Mock MockHistoryChecker { 'I am the It mock.' }
            MockHistoryChecker | Should Be 'I am the It mock.'
        }

        It 'Reports 2 context-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 2
        }

        It 'Reports 3 describe-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 3 -Scope Describe
        }
    }

    It 'Reports 3 describe-scoped calls using the default scope in a Describe block' {
        Assert-MockCalled MockHistoryChecker -Exactly 3
    }
}

Describe "Using a single no param Describe" {
    Mock FunctionUnderTest {return "I am the describe mock test"}

    Context "With a context mocking the same function with no params"{
        Mock FunctionUnderTest {return "I am the context mock test"}
        It "Should use the context mock" {
            FunctionUnderTest | should be "I am the context mock test"
        }
    }
}

Describe 'Dot Source Test' {
    # This test is only meaningful if this test file is dot-sourced in the global scope.  If it's executed without
    # dot-sourcing or run by Invoke-Pester, there's no problem.

    function TestFunction { Test-Path -Path 'Test' }
    Mock Test-Path { }

    $null = TestFunction

    It "Calls the mock with parameter 'Test'" {
        Assert-MockCalled Test-Path -Exactly 1 -ParameterFilter { $Path -eq 'Test' }
    }

    It "Doesn't call the mock with any other parameters" {
        Assert-MockCalled Test-Path -Exactly 0 -ParameterFilter { $Path -ne 'Test' }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters' {
    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { Get-ChildItem -Path Cert:\ -CodeSigningCert } | Should Not Throw
        Assert-MockCalled Get-ChildItem
    }
}

Describe 'Mocking functions with dynamic parameters' {

    # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
    # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

    function Get-Greeting {
        [CmdletBinding()]
        param (
            $Name
        )

        DynamicParam {
            if ($Name -cmatch '\b[a-z]') {
                $Attributes = New-Object Management.Automation.ParameterAttribute
                $Attributes.ParameterSetName = "__AllParameterSets"
                $Attributes.Mandatory = $false

                $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                $AttributeCollection.Add($Attributes)

                $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $ParamDictionary.Add("Capitalize", $Dynamic)
                $ParamDictionary
            }
        }

        end
        {
            if($PSBoundParameters.Capitalize) {
                $Name = [regex]::Replace(
                    $Name,
                    '\b\w',
                    { $args[0].Value.ToUpper() }
                )
            }

            "Welcome $Name!"
        }
    }

    $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
    Mock Get-Greeting -MockWith $mockWith -ParameterFilter { [bool]$Capitalize }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
        Assert-MockCalled Get-Greeting
    }

    Context 'When a variable with the same name as a dynamic parameter exists in a parent scope' {
        $Capitalize = $false

        It 'Still sets the parameter variable properly in the parameter filter and mock body' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting -Scope It
        }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters in a module' {
    New-Module -Name TestModule {
        function PublicFunction   { Get-ChildItem -Path Cert:\ -CodeSigningCert }
    } | Import-Module -Force

    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should Not Throw
        Assert-MockCalled Get-ChildItem -ModuleName TestModule
    }

    Remove-Module TestModule -Force
}

Describe 'Mocking functions with dynamic parameters in a module' {
    New-Module -Name TestModule {
        function PublicFunction { Get-Greeting -Name lowercase -Capitalize }

        $script:DoDynamicParam = $true

        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting {
            [CmdletBinding()]
            param (
                $Name
            )

            DynamicParam {
                # This check is here to make sure the mocked version can still work if the
                # original function's dynamicparam block relied on script-scope variables.
                if (-not $script:DoDynamicParam) { return }

                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }
    } | Import-Module -Force

    $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
    Mock Get-Greeting -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Capitalize }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should Not Throw
        Assert-MockCalled Get-Greeting -ModuleName TestModule
    }

    Remove-Module TestModule -Force
}

Describe 'DynamicParam blocks in other scopes' {
    New-Module -Name TestModule1 {
        $script:DoDynamicParam = $true

        function DynamicParamFunction {
            [CmdletBinding()]
            param ( )

            DynamicParam {
                if ($script:DoDynamicParam)
                {
                    Get-MockDynamicParameters -CmdletName Get-ChildItem -Parameters @{ Path = [string[]]'Cert:\' }
                }
            }

            end
            {
                'I am the original function'
            }
        }
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function CallingFunction
        {
            DynamicParamFunction -CodeSigningCert
        }

        function CallingFunction2 {
            [CmdletBinding()]
            param (
                [ValidateScript({ [bool](DynamicParamFunction -CodeSigningCert) })]
                [string]
                $Whatever
            )
        }
    } | Import-Module -Force

    Mock DynamicParamFunction { if ($CodeSigningCert) { 'I am the mocked function' } } -ModuleName TestModule2

    It 'Properly evaluates dynamic parameters when called from another scope' {
        CallingFunction | Should Be 'I am the mocked function'
    }

    It 'Properly evaluates dynamic parameters when called from another scope when the call is from a ValidateScript block' {
        CallingFunction2 -Whatever 'Whatever'
    }

    Remove-Module TestModule1 -Force
    Remove-Module TestModule2 -Force
}

Describe 'Parameter Filters and Common Parameters' {
    function Test-Function { [CmdletBinding()] param ( ) }

    Mock Test-Function { } -ParameterFilter { $VerbosePreference -eq 'Continue' }

    It 'Applies common parameters correctly when testing the parameter filter' {
        { Test-Function -Verbose } | Should Not Throw
        Assert-MockCalled Test-Function
        Assert-MockCalled Test-Function -ParameterFilter { $VerbosePreference -eq 'Continue' }
    }
}

Describe "Mocking Get-ItemProperty" {
    Mock Get-ItemProperty { New-Object -typename psobject -property @{ Name = "fakeName" } }
    It "Does not fail with NotImplementedException" {
        Get-ItemProperty -Path "HKLM:\Software\Key\" -Name "Property" | Select -ExpandProperty Name | Should Be fakeName
    }
}

Describe 'When mocking a command with parameters that match internal variable names' {
    function Test-Function
    {
        [CmdletBinding()]
        param (
            [string] $ArgumentList,
            [int] $FunctionName,
            [double] $ModuleName
        )
    }

    Mock Test-Function { return 'Mocked!' }

    It 'Should execute the mocked command successfully' {
        { Test-Function } | Should Not Throw
        Test-Function | Should Be 'Mocked!'
    }
}

# SIG # Begin signature block
# MIIatwYJKoZIhvcNAQcCoIIaqDCCGqQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUxWlAsFnFWsyNdP9Wv24u+y/E
# wGOgghV6MIIEuzCCA6OgAwIBAgITMwAAAF3JyvZpIzdoUAAAAAAAXTANBgkqhkiG
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSGYCsRTu7XKWlD
# NaRrTGK/6bXRHzBgBgorBgEEAYI3AgEMMVIwUKAmgCQAVwBpAG4AZABvAHcAcwAg
# AFAAbwB3AGUAcgBTAGgAZQBsAGyhJoAkaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3Bvd2Vyc2hlbGwgMA0GCSqGSIb3DQEBAQUABIIBADjJbnFYNx/qJO4s9mRn0V4f
# ybEnZbp4E0FTyDGTVKJmSCRWeXvqyzEdHMw9Gg0PQQUzRuAC5IPHJtP49e0k/BxL
# 6m6myNKfP2iPeq16D69aWGNbVpK7ZdbeDcBJWCjwYKjcTvUjTeAdyjQ5o8iwD6Ag
# NQQsS1kWx3yL9dFI3KCVeTfZS3DqRqaetKnthBqpL2FUwEmd/NpW3wgeI6jmjIx1
# LrUXoodd9oophcexzNzRYJuEfrzVmzvw/K3kQtW8DLQb1f1o8e0/47EZ0crTomC0
# eRAEJNCW4oxJ8tq68CzeLipxHspgBC9CB3ytg65tcngXx2dS78rBLGeobyvh12Wh
# ggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBAhMzAAAAXcnK9mkjN2hQAAAAAABdMAkGBSsOAwIaBQCgXTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTAzMDUyMzU5
# MDhaMCMGCSqGSIb3DQEJBDEWBBSRg1L2UsVFqsifJi861RUZZdZivDANBgkqhkiG
# 9w0BAQUFAASCAQBA3Yqq7SGE0dStc2MO1NjPxEy4SaCYVD5Lt7xmUDhhIVlTfZlS
# jPbkvn5JvphE5wIle3Abl215yX9ed/ccWsQobvlDB3bq0I5N1CbclcWkBuFUKkdP
# juTGl/l/5obpHwVtx/NgVcgXHLgv6mPacKtVKoSoTlj3TVrOZBHcFP+O74DGO6s0
# Ekaeksh9GRejcRFLK9jJqbD9kIEG2S/JxjZXrE8o4pMhqajn8EptMWA0Zn8G6Dkc
# 9njf2uOthUyYRu1CoLZjY72pcksqKoS9NvMd7iU9pInnlNP608cKIUn21GaB8IDv
# x/GEegplXstWlxRNAGr/gMHJjxcxkhiSLdTc
# SIG # End signature block
