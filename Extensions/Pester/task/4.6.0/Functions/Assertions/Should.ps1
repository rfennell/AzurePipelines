function Parse-ShouldArgs([object[]] $shouldArgs) {
    if ($null -eq $shouldArgs) {
        $shouldArgs = @()
    }

    $parsedArgs = @{
        PositiveAssertion = $true
        ExpectedValue     = $null
    }

    $assertionMethodIndex = 0
    $expectedValueIndex = 1

    if ($shouldArgs.Count -gt 0 -and $shouldArgs[0] -eq "not") {
        $parsedArgs.PositiveAssertion = $false
        $assertionMethodIndex += 1
        $expectedValueIndex += 1
    }

    if ($assertionMethodIndex -lt $shouldArgs.Count) {
        $parsedArgs.AssertionMethod = "$($shouldArgs[$assertionMethodIndex])"
    }
    else {
        throw 'You cannot call Should without specifying an assertion method.'
    }

    if ($expectedValueIndex -lt $shouldArgs.Count) {
        $parsedArgs.ExpectedValue = $shouldArgs[$expectedValueIndex]
    }

    return $parsedArgs
}

function Get-FailureMessage($assertionEntry, $negate, $value, $expected) {
    if ($negate) {
        $failureMessageFunction = $assertionEntry.GetNegativeFailureMessage
    }
    else {
        $failureMessageFunction = $assertionEntry.GetPositiveFailureMessage
    }

    return (& $failureMessageFunction $value $expected)
}

function New-ShouldErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText) {
    $exception = & $SafeCommands['New-Object'] Exception $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = & $SafeCommands['New-Object'] Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Should {
    <#
    .SYNOPSIS
    Should is a keyword what is used to define an assertion inside It block.

    .DESCRIPTION
    Should is a keyword what is used to define an assertion inside the It block.
    Should provides assertion methods for verify assertion e.g. comparing objects.
    If assertion is not met the test fails and an exception is throwed up.

    Should can be used more than once in the It block if more than one assertion
    need to be verified. Each Should keywords need to be located in a new line.
    Test will be passed only when all assertion will be met (logical conjuction).

    .LINK
    about_Should
    about_Pester
#>

    [CmdletBinding(DefaultParameterSetName = 'Legacy')]
    param (
        [Parameter(ParameterSetName = 'Legacy', Position = 0)]
        [object] $__LegacyArg1,

        [Parameter(ParameterSetName = 'Legacy', Position = 1)]
        [object] $__LegacyArg2,

        [Parameter(ParameterSetName = 'Legacy', Position = 2)]
        [object] $__LegacyArg3,

        [Parameter(ValueFromPipeline = $true)]
        [object] $ActualValue
    )

    dynamicparam {
        Get-AssertionDynamicParams
    }

    begin {
        $inputArray = New-Object System.Collections.Generic.List[PSObject]

        if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
            $parsedArgs = Parse-ShouldArgs ($__LegacyArg1, $__LegacyArg2, $__LegacyArg3)
            $entry = Get-AssertionOperatorEntry -Name $parsedArgs.AssertionMethod
            if ($null -eq $entry) {
                throw "'$($parsedArgs.AssertionMethod)' is not a valid Should operator."
            }
        }
    }

    process {
        $inputArray.Add($ActualValue)
    }

    end {
        $lineNumber = $MyInvocation.ScriptLineNumber
        $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
        $file = $MyInvocation.ScriptName

        if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
            if ($inputArray.Count -eq 0) {
                Invoke-LegacyAssertion $entry $parsedArgs $null $file $lineNumber $lineText
            }
            elseif ($entry.SupportsArrayInput) {
                Invoke-LegacyAssertion $entry $parsedArgs $inputArray.ToArray() $file $lineNumber $lineText
            }
            else {
                foreach ($object in $inputArray) {
                    Invoke-LegacyAssertion $entry $parsedArgs $object $file $lineNumber $lineText
                }
            }
        }
        else {
            $negate = $false
            if ($PSBoundParameters.ContainsKey('Not')) {
                $negate = [bool]$PSBoundParameters['Not']
            }

            $null = $PSBoundParameters.Remove('ActualValue')
            $null = $PSBoundParameters.Remove($PSCmdlet.ParameterSetName)
            $null = $PSBoundParameters.Remove('Not')

            $entry = Get-AssertionOperatorEntry -Name $PSCmdlet.ParameterSetName

            if ($inputArray.Count -eq 0) {
                Invoke-Assertion $entry $PSBoundParameters $null $file $lineNumber $lineText -Negate:$negate
            }
            elseif ($entry.SupportsArrayInput) {
                Invoke-Assertion $entry $PSBoundParameters $inputArray.ToArray() $file $lineNumber $lineText -Negate:$negate
            }
            else {
                foreach ($object in $inputArray) {
                    Invoke-Assertion $entry $PSBoundParameters $object $file $lineNumber $lineText -Negate:$negate
                }
            }
        }
    }
}

function Invoke-LegacyAssertion($assertionEntry, $shouldArgs, $valueToTest, $file, $lineNumber, $lineText) {
    # $expectedValueSplat = @(
    #     if ($null -ne $shouldArgs.ExpectedValue)
    #     {
    #         ,$shouldArgs.ExpectedValue
    #     }
    # )

    $negate = -not $shouldArgs.PositiveAssertion

    $testResult = (& $assertionEntry.Test $valueToTest $shouldArgs.ExpectedValue -Negate:$negate)
    if (-not $testResult.Succeeded) {
        throw ( New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText )
    }
}

function Invoke-Assertion {
    param (
        [object] $AssertionEntry,
        [System.Collections.IDictionary] $BoundParameters,
        [object] $valuetoTest,
        [string] $File,
        [int] $LineNumber,
        [string] $LineText,
        [switch] $Negate
    )

    $testResult = & $AssertionEntry.Test -ActualValue $valuetoTest -Negate:$Negate @BoundParameters
    if (-not $testResult.Succeeded) {
        throw ( New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText )
    }
    else {
        #extract data to return if there are any on the object
        $data = $testResult.psObject.Properties.Item('Data')
        if ($data) {
            $data.Value
        }
    }
}

function Format-Because ([string] $Because) {
    if ($null -eq $Because) {
        return
    }

    $bcs = $Because.Trim()
    if ([string]::IsNullOrEmpty($bcs)) {
        return
    }

    " because $($bcs -replace 'because\s'),"
}

# SIG # Begin signature block
# MIIcVgYJKoZIhvcNAQcCoIIcRzCCHEMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmJtyLx4syWCzZX4ehaiiejg+
# FQSggheFMIIFDjCCA/agAwIBAgIQAkpwj7JyQh8pn8abOhJIUDANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE4MTEyNzAwMDAwMFoXDTE5MTIw
# MjEyMDAwMFowSzELMAkGA1UEBhMCQ1oxDjAMBgNVBAcTBVByYWhhMRUwEwYDVQQK
# DAxKYWt1YiBKYXJlxaExFTATBgNVBAMMDEpha3ViIEphcmXFoTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAKgBHbFhyeivpcxqohppsNGucvZvAyvg3gKT
# M1B6EpI18C6NN7FXWTPym9ffe1kS5ZeYDKW98NcOBArm28mdgip6WcUQ0qMt9lI8
# EsTa4Ohlkj/AYYUdgh96zgIl/V+MIO3JVAY3OwkWjkfDKVbzrNG5IcO5yKfwnt8/
# a238OS/VlFNsNELGW7XIQBD/rKrEDY8JZReIrkz6sGdba+3OcXBClp513JFniVgD
# vOXo2RDUqtnpFuCdsthe8hWXtpbcjIpFykLzNcNA+2GIbwbBG5XKXsN0ZJsbrWVA
# RiwNoDN+Fh3pe5rxGVfMDHdXt1I0KpJbFlGB4P7Sy2Mh5CTwRyUCAwEAAaOCAcUw
# ggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBSw
# +E81VeF9HSgNxUARWWqXFWZrZjAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYI
# KwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRp
# Z2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMEwGA1UdIARFMEMwNwYJ
# YIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNv
# bS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYwJAYIKwYBBQUHMAGGGGh0
# dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcwAoZCaHR0cDovL2NhY2Vy
# dHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRENvZGVTaWduaW5n
# Q0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAFltMO2WO9L/
# fLYIbzeQIilLoH97l9PYQAPz5uNh4R8l5w6Y/SgusY3+k+KaNONXSTcSL1KP9Pn3
# 2y11xqFwdrJbRxC8i5x2KFvGDGkvpDWFsX24plq5brRL+qerkyTwRgSRUiU/luvq
# BTYQ/eQmgikkIB6l7f6m2An8qtOkNfDM0D/eVJS3+/TRSMIPmBp9Ubktacp8sNIK
# JacAkVl1zjucvVhyuWOFsIFtPn25XsiNu4d87pUyMzm8Vehyl1xxLNH/6cqxCkyG
# FXCrav1knrz22qD5b8wrwUYnmCt37BeBX6KvpSXpafDdAok5QkPs7TeJVcVVPdb4
# tqaLNvGOpBgwggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3
# DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3Vy
# ZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJ
# RCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl
# +YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQz
# UHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNx
# PqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqr
# hPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItq
# cyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/
# AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEF
# BQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBD
# BggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2Ny
# bDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDig
# NoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9v
# dENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYc
# aHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4E
# FgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0c
# LToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9x
# jmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpx
# KAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUI
# QjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhiz
# gZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggZq
# MIIFUqADAgECAhADAZoCOv9YsWvW1ermF/BmMA0GCSqGSIb3DQEBBQUAMGIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTAe
# Fw0xNDEwMjIwMDAwMDBaFw0yNDEwMjIwMDAwMDBaMEcxCzAJBgNVBAYTAlVTMREw
# DwYDVQQKEwhEaWdpQ2VydDElMCMGA1UEAxMcRGlnaUNlcnQgVGltZXN0YW1wIFJl
# c3BvbmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKNkXfx8s+CC
# NeDg9sYq5kl1O8xu4FOpnx9kWeZ8a39rjJ1V+JLjntVaY1sCSVDZg85vZu7dy4Xp
# X6X51Id0iEQ7Gcnl9ZGfxhQ5rCTqqEsskYnMXij0ZLZQt/USs3OWCmejvmGfrvP9
# Enh1DqZbFP1FI46GRFV9GIYFjFWHeUhG98oOjafeTl/iqLYtWQJhiGFyGGi5uHzu
# 5uc0LzF3gTAfuzYBje8n4/ea8EwxZI3j6/oZh6h+z+yMDDZbesF6uHjHyQYuRhDI
# jegEYNu8c3T6Ttj+qkDxss5wRoPp2kChWTrZFQlXmVYwk/PJYczQCMxr7GJCkawC
# wO+k8IkRj3cCAwEAAaOCAzUwggMxMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8E
# AjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIIBvwYDVR0gBIIBtjCCAbIwggGh
# BglghkgBhv1sBwEwggGSMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2Vy
# dC5jb20vQ1BTMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAA
# bwBmACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMA
# dABpAHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgA
# ZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgA
# ZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4A
# dAAgAHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAA
# YQBuAGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIA
# ZQBpAG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTAf
# BgNVHSMEGDAWgBQVABIrE5iymQftHt+ivlcNK2cCzTAdBgNVHQ4EFgQUYVpNJLZJ
# Mp1KKnkag0v0HonByn0wfQYDVR0fBHYwdDA4oDagNIYyaHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5jcmwwOKA2oDSGMmh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMHcG
# CCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURDQS0xLmNydDANBgkqhkiG9w0BAQUFAAOCAQEAnSV+GzNN
# siaBXJuGziMgD4CH5Yj//7HUaiwx7ToXGXEXzakbvFoWOQCd42yE5FpA+94GAYw3
# +puxnSR+/iCkV61bt5qwYCbqaVchXTQvH3Gwg5QZBWs1kBCge5fH9j/n4hFBpr1i
# 2fAnPTgdKG86Ugnw7HBi02JLsOBzppLA044x2C/jbRcTBu7kA7YUq/OPQ6dxnSHd
# FMoVXZJB2vkPgdGZdA0mxA5/G7X1oPHGdwYoFenYk+VVFvC7Cqsc21xIJ2bIo4sK
# HOWV2q7ELlmgYd3a822iYemKC23sEhi991VUQAOSK2vCUcIKSK+w1G7g9BQKOhvj
# jz3Kr2qNe9zYRDCCBs0wggW1oAMCAQICEAb9+QOWA63qAArrPye7uhswDQYJKoZI
# hvcNAQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNz
# dXJlZCBJRCBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFow
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBD
# QS0xMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBz
# QHDSnlZUXKnE0kEGj8kz/E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r
# 7a2wcTHrzzpADEZNk+yLejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD
# /6b3+6LNb3Mj/qxWBZDwMiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z
# 8rwMK5nQxl0SQoHhg26Ccz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2
# zkBdXPao8S+v7Iki8msYZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9
# BwSiCQIDAQABo4IDejCCA3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsG
# AQUFBwMBBggrBgEFBQcDAgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCC
# AdIGA1UdIASCAckwggHFMIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEW
# Lmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0w
# ggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgA
# aQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQA
# ZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcA
# aQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwA
# eQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkA
# YwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEA
# cgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIA
# eQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQI
# MAYBAf8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgw
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+
# Vw0rZwLNMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3
# DQEBBQUAA4IBAQBGUD7Jtygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKy
# XGGinJXDUOSCuSPRujqGcq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+er
# Ys37iy2QwsDStZS9Xk+xBdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+c
# dkvtX8JLFuRLcEwAiR78xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeS
# DY2xaYxP+1ngIw/Sqq4AfO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGt
# STGDR5V3cdyxG0tLHBCcdxTBnU8vWpUIKRAmMYIEOzCCBDcCAQEwgYYwcjELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENv
# ZGUgU2lnbmluZyBDQQIQAkpwj7JyQh8pn8abOhJIUDAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# f94d8Jq9/dmN6qeXC4GQCKktRiwwDQYJKoZIhvcNAQEBBQAEggEApDcVf9VkF4oS
# aSZgJ8anOei/D7PeSJ029ZG4133PgzWRbm0domwY9ibbt/7n/eX0iaTVsCnRGl5r
# WsEjhRyDsOP69JkmqJFKVN8VgeoPhif62ZLtghovqU8gSosIkPGmRbTTiqMSWjz0
# hh5BcgSqFVut0qpFA7pUOorlfGAH7bYcLRx+8OFBCAsCYFsjkW7lGtjSE7y4dZUx
# OjvSPYK0TQcjB3UUIPEjiOLB/snjETQpIw7n++NHKVpvJkLHYGsR12xHjpYlEzAd
# 0QLQcSgD1l/ZZdfX9AMVpta6aXfcfbHxKu1tNeaS/Nl9AXAJa0JwHIhiHWzKK0tt
# uwIIwpzOPaGCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQAwGa
# Ajr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTkwMTIxMTk0ODQyWjAjBgkqhkiG9w0BCQQx
# FgQUgcs65T6OGdCfxx3VycMNeuJ0tCYwDQYJKoZIhvcNAQEBBQAEggEAM2il25lq
# rYHvwykc0eLRSplRDp41DhZwdtvkf9BPS8b4D1KKi3Q5jnbFwhdgAOibSMLKHfiQ
# 7UPCWWTP98KcmtKJl7lOgqT8U60j2XoW+QSpFT6IrRTitok9K6uFS/GNJufbkKDV
# 6FCvUQi7jsRSOmgyZlSHvth2jQJ6AozvpkKTCKbSCeYSumcMlq+r+1Ef9WWUeZEE
# PUNdJMto23A8EhTcjAD/lF2lIwoGEFRKqb20tr2tzOivvE3LcX1tecNyeV+C0rSp
# 5iex4LDLSuN4+4u/Xwm95Zl7XfmvqYnflBurglepokHT9e8v/2rO2YXhnOj4+R/I
# Xo5G0F2+f2MTGw==
# SIG # End signature block
