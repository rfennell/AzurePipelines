function Get-HumanTime($Seconds) {
    if($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = 's'
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = 'ms'
    }
    return "$time$unit"
}

function GetFullPath ([string]$Path) {
    if (-not [System.IO.Path]::IsPathRooted($Path))
    {
        $Path = Join-Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation $Path
    }

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Export-PesterResults
{
    param (
        $PesterState,
        [string] $Path,
        [string] $Format
    )

    switch ($Format)
    {
        'LegacyNUnitXml' { Export-NUnitReport -PesterState $PesterState -Path $Path -LegacyFormat }
        'NUnitXml'       { Export-NUnitReport -PesterState $PesterState -Path $Path }

        default
        {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}
function Export-NUnitReport {
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        $PesterState,

        [parameter(Mandatory=$true)]
        [String]$Path,

        [switch] $LegacyFormat
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path

    $Path = GetFullPath -Path $Path

    $settings = New-Object -TypeName Xml.XmlWriterSettings -Property @{
        Indent = $true
        NewLineOnAttributes = $false
    }

    $xmlWriter = $null
    try {
        $xmlWriter = [Xml.XmlWriter]::Create($Path,$settings)

        Write-NUnitReport -XmlWriter $xmlWriter -PesterState $PesterState -LegacyFormat:$LegacyFormat

        $xmlWriter.Flush()
    }
    finally
    {
        if ($null -ne $xmlWriter) {
            try { $xmlWriter.Close() } catch {}
        }
    }
}

function Write-NUnitReport($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    Write-NUnitTestResultAttributes @PSBoundParameters
    Write-NUnitTestResultChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestResultAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('xmlns','xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi','noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    $XmlWriter.WriteAttributeString('name','Pester')
    $XmlWriter.WriteAttributeString('total', $PesterState.TotalCount)
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $PesterState.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', '0')
    $XmlWriter.WriteAttributeString('inconclusive', $PesterState.PendingCount)
    $XmlWriter.WriteAttributeString('ignored', '0')
    $XmlWriter.WriteAttributeString('skipped', $PesterState.SkippedCount)
    $XmlWriter.WriteAttributeString('invalid', '0')
    $date = Get-Date
    $XmlWriter.WriteAttributeString('date', (Get-Date -Date $date -Format 'yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', (Get-Date -Date $date -Format 'HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    Write-NUnitEnvironmentInformation @PSBoundParameters
    Write-NUnitCultureInformation @PSBoundParameters

    $XmlWriter.WriteStartElement('test-suite')
    Write-NUnitGlobalTestSuiteAttributes @PSBoundParameters

    $XmlWriter.WriteStartElement('results')

    Write-NUnitDescribeElements @PSBoundParameters

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnitCultureInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitGlobalTestSuiteAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', 'Powershell')

    # TODO: This used to be writing $PesterState.Path, back when that was a single string (and existed.)
    #       Better would be to produce a test suite for each resolved file, rather than for the value
    #       of the path that was passed to Invoke-Pester.

    $XmlWriter.WriteAttributeString('name', 'Pester')
    $XmlWriter.WriteAttributeString('executed', 'True')

    $isSuccess = $PesterState.FailedCount -eq 0
    $result = Get-ParentResult $PesterState
    $XmlWriter.WriteAttributeString('result', $result)
    $XmlWriter.WriteAttributeString('success',[string]$isSuccess)
    $XmlWriter.WriteAttributeString('time',(Convert-TimeSpan $PesterState.Time))
    $XmlWriter.WriteAttributeString('asserts','0')
}

function Write-NUnitDescribeElements($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $Describes = $PesterState.TestResult | Group-Object -Property Describe
    if ($null -ne $Describes)
    {
        foreach ($currentDescribe in $Describes)
        {
            $DescribeInfo = Get-TestSuiteInfo $currentDescribe

            #Write test suites
            $XmlWriter.WriteStartElement('test-suite')

            if ($LegacyFormat) { $suiteType = 'PowerShell' } else { $suiteType = 'TestFixture' }

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $DescribeInfo -TestSuiteType $suiteType -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

            $XmlWriter.WriteStartElement('results')

            Write-NUnitDescribeChildElements -TestResults $currentDescribe.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeInfo.Name

            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }
}

function Get-TestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo]$TestSuiteGroup)
{
    $suite = @{
        resultMessage = 'Failure'
        success = 'False'
        totalTime = '0.0'
        name = $TestSuiteGroup.Name
        description = $TestSuiteGroup.Name
    }

    #calculate the time first, I am converting the time into string in the TestCases
    $suite.totalTime = (Get-TestTime $TestSuiteGroup.Group)
    $suite.success = (Get-TestSuccess $TestSuiteGroup.Group)
    $suite.resultMessage = Get-GroupResult $TestSuiteGroup.Group
    $suite
}

function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests)
    {
        foreach ($test in $tests)
        {
            $totalTime += $test.time
        }
    }

    Convert-TimeSpan -TimeSpan $totalTime
}
function Convert-TimeSpan {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $TimeSpan
    )
    process {
        if ($TimeSpan) {
            [string][math]::round(([TimeSpan]$TimeSpan).totalseconds,4)
        }
        else
        {
            '0'
        }
    }
}
function Get-TestSuccess($tests) {
    $result = $true
    if ($tests)
    {
        foreach ($test in $tests) {
            if (-not $test.Passed) {
                $result = $false
                break
            }
        }
    }
    [String]$result
}
function Write-NUnitTestSuiteAttributes($TestSuiteInfo, [System.Xml.XmlWriter] $XmlWriter, [string] $TestSuiteType, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('result', $TestSuiteInfo.resultMessage)
    $XmlWriter.WriteAttributeString('success', $TestSuiteInfo.success)
    $XmlWriter.WriteAttributeString('time',$TestSuiteInfo.totalTime)
    $XmlWriter.WriteAttributeString('asserts','0')

    if (-not $LegacyFormat)
    {
        $XmlWriter.WriteAttributeString('description', $TestSuiteInfo.Description)
    }
}

function Write-NUnitDescribeChildElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName)
{
    $suites = $TestResults | Group-Object -Property ParameterizedSuiteName

    foreach ($suite in $suites)
    {
        if ($suite.Name)
        {
            $suiteInfo = Get-TestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            if (-not $LegacyFormat)
            {
                $suiteInfo.Name = "$DescribeName.$($suiteInfo.Name)"
            }

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -TestSuiteType 'ParameterizedTest' -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

            $XmlWriter.WriteStartElement('results')
        }

        Write-NUnitTestCaseElements -TestResults $suite.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $suite.Name

        if ($suite.Name)
        {
            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }
}

function Write-NUnitTestCaseElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    foreach ($testResult in $TestResults)
    {
        $XmlWriter.WriteStartElement('test-case')

        Write-NUnitTestCaseAttributes -TestResult $testResult -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $ParameterizedSuiteName

        $XmlWriter.WriteEndElement()
    }
}

function Write-NUnitTestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    $testName = $TestResult.Name

    if (-not $LegacyFormat)
    {
        if ($testName -eq $ParameterizedSuiteName)
        {
            $paramString = ''
            if ($null -ne $TestResult.Parameters)
            {
                $params = @(
                    foreach ($value in $TestResult.Parameters.Values)
                    {
                        if ($null -eq $value)
                        {
                            'null'
                        }
                        elseif ($value -is [string])
                        {
                            '"{0}"' -f $value
                        }
                        else
                        {
                            #do not use .ToString() it uses the current culture settings
                            #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
                            [string]$value
                        }
                    }
                )

                $paramString = $params -join ','
            }

            $testName = "$testName($paramString)"
        }

        $testName = "$DescribeName.$testName"

        $XmlWriter.WriteAttributeString('description', $TestResult.Name)
    }

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

    switch ($TestResult.Result)
    {
        Passed
        {
            $XmlWriter.WriteAttributeString('result', 'Success')
            break
        }
        Skipped
        {
            $XmlWriter.WriteAttributeString('result', 'Skipped')
            break
        }
        Pending
        {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            break
        }
        Failed
        {
            $XmlWriter.WriteAttributeString('result', 'Failure')
            $XmlWriter.WriteStartElement('failure')
            $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
            $XmlWriter.WriteElementString('stack-trace', $TestResult.StackTrace)
            $XmlWriter.WriteEndElement() # Close failure tag
            break
        }
    }
}
function Get-RunTimeEnvironment() {
    $osSystemInformation = (Get-WmiObject Win32_OperatingSystem)
    @{
        'nunit-version' = '2.5.8.0'
        'os-version' = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        cwd = (Get-Location).Path #run path
        'machine-name' = $env:ComputerName
        user = $env:Username
        'user-domain' = $env:userDomain
        'clr-version' = [string]$PSVersionTable.ClrVersion
    }
}

function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

function Get-ParentResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($inputObject.FailedCount  -gt 0) { return 'Failure' }
    if ($InputObject.SkippedCount -gt 0) { return 'Skipped' }
    if ($InputObject.PendingCount -gt 0) { return 'Inconclusive' }
    return 'Success'
}

function Get-GroupResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($InputObject |  Where {$_.Result -eq 'Failed'}) { return 'Failure' }
    if ($InputObject |  Where {$_.Result -eq 'Skipped'}) { return 'Skipped' }
    if ($InputObject |  Where {$_.Result -eq 'Pending'}) { return 'Inconclusive' }
    return 'Success'
}

# SIG # Begin signature block
# MIIatwYJKoZIhvcNAQcCoIIaqDCCGqQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3tMqzGMpFjasI4FxqiHPbN9y
# 4legghV6MIIEuzCCA6OgAwIBAgITMwAAAF3JyvZpIzdoUAAAAAAAXTANBgkqhkiG
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSVGTn50DjvKV/k
# o7NPsZGew6MF6TBgBgorBgEEAYI3AgEMMVIwUKAmgCQAVwBpAG4AZABvAHcAcwAg
# AFAAbwB3AGUAcgBTAGgAZQBsAGyhJoAkaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3Bvd2Vyc2hlbGwgMA0GCSqGSIb3DQEBAQUABIIBAFVn+kiB7gXV3+CRnfwS5/OW
# GVPB0p8JMGNF1aYoZgNwgivbw4OY4jpK6XuHiCKsBYZ9Zvb+Qy/MakZfxtOEeWY3
# 3SDMvDLnofKvdx5IMPhl6/pPMoVncOEkiYC7LAcpTcpjFtCqDJ1TZ2le5cfHoFoE
# vryNy0Fe6D790yrToaTAyxo/JMRurlF7w9o6Y96gCJP+XhVoiIxSnOelR5DTmL5E
# YqHn7tU1CnrZCleLd2UgXdGDzpHiiMLgBjI7eEC2l1gMS6azrQmDg/2yCSdCVrVo
# rYzYuRb1cRLmuPxCPsoZ9mkdcd7l7oXYlm9VRtIrrxkIAH4jN82ADDjbYVjfxQ6h
# ggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBAhMzAAAAXcnK9mkjN2hQAAAAAABdMAkGBSsOAwIaBQCgXTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTAzMDUyMzU5
# MDhaMCMGCSqGSIb3DQEJBDEWBBQvWLRNLID/LEI/Aq6eBW3uMnN8AjANBgkqhkiG
# 9w0BAQUFAASCAQBOYUaYtKLSJpMwts8pOI3MO2Y5MS6nG1qeig6GQ8oEOAs8Lg01
# lyH5tIgclxl0RXHB/WOf8YCIQvJXo1XnLpIyN/FLaJYPvP+5VMvY3bPnVyJTLrln
# ZpCP8h35OEflZYyZkMaZlEYOHN/x1w3ppueUtsn7NBRLhJ/G1WfYzyGGZLRYAAU8
# schhOm+bnOzvSRW8K1VHwZgQ0SWlx6vlftdsLjTNGa0dFTN+b8S65SdYeMwfrLy0
# YvDOZhXQRHcscIBxjIVL9o2upkbYLlYVJ9Zkdec4QMInCSwj/+l9guA5xMjvL6DZ
# g849eabNREynRoG82peJoQkt6PurFh4KCmbo
# SIG # End signature block
