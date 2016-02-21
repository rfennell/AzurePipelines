#
function New-TestDrive ([Switch]$PassThru) {
    $Path = New-RandomTempDirectory
    $DriveName = "TestDrive"

    if (-not (Microsoft.PowerShell.Management\Test-Path -Path $Path))
    {
        New-Item -ItemType Container -Path $Path | Out-Null
    }

    #setup the test drive
    if ( -not (Test-Path "${DriveName}:\") )
    {
        New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $Path -Scope Global -Description "Pester test drive" | Out-Null
    }

    #publish the global TestDrive variable used in few places within the module
    if (-not (Test-Path "Variable:Global:DriveName"))
    {
        New-Variable -Name $DriveName -Scope Global -Value $Path
    }

    if ( $PassThru ) { Get-PSDrive -Name $DriveName }
}


function Clear-TestDrive ([String[]]$Exclude) {
    $Path = (Microsoft.PowerShell.Management\Get-PSDrive -Name TestDrive).Root
    if (Microsoft.PowerShell.Management\Test-Path -Path $Path )
    {
        #Get-ChildItem -Exclude did not seem to work with full paths
        Microsoft.PowerShell.Management\Get-ChildItem -Recurse -Path $Path |
        Microsoft.PowerShell.Utility\Sort-Object -Descending  -Property "FullName" |
        Microsoft.PowerShell.Core\Where-Object { $Exclude -NotContains $_.FullName } |
        Microsoft.PowerShell.Management\Remove-Item -Force -Recurse
    }
}

function New-RandomTempDirectory {
    do
    {
        $Path = Join-Path -Path $env:TEMP -ChildPath ([Guid]::NewGuid())
    } until (-not (  Microsoft.PowerShell.Management\Test-Path -Path $Path ))

    New-Item -ItemType Container -Path $Path
}

function Get-TestDriveItem {
    #moved here from Pester.psm1
    param( [string]$Path )

    Assert-DescribeInProgress -CommandName Get-TestDriveItem
    Get-Item $(Join-Path $TestDrive $Path )
}

function Get-TestDriveChildItem {
    $Path = (Microsoft.PowerShell.Management\Get-PSDrive -Name TestDrive).Root
    if (Microsoft.PowerShell.Management\Test-Path -Path $Path )
    {
        Microsoft.PowerShell.Management\Get-ChildItem -Recurse -Path $Path
    }
}

function Remove-TestDrive {

    $DriveName = "TestDrive"
    $Drive = Get-PSDrive -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    $Path = ($Drive).Root


    if ($pwd -like "$DriveName*" ) {
        #will staying in the test drive cause issues?
        #TODO review this
        Write-Warning -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive )
    {
        $Drive | Remove-PSDrive -Force -ErrorAction $script:IgnoreErrorPreference
    }

    if (Microsoft.PowerShell.Management\Test-Path -Path $Path)
    {
        Microsoft.PowerShell.Management\Remove-Item -Path $Path -Force -Recurse
    }

    if (Get-Variable -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference) {
        Remove-Variable -Scope Global -Name $DriveName -Force
    }
}

function Setup {
    #included for backwards compatibility
    param(
    [switch]$Dir,
    [switch]$File,
    $Path,
    $Content = "",
    [switch]$PassThru
    )

    Assert-DescribeInProgress -CommandName Setup

    $TestDriveName = Get-PSDrive TestDrive | Select -ExpandProperty Root

    if ($Dir) {
        $item = New-Item -Name $Path -Path "${TestDriveName}\" -Type Container -Force
    }
    if ($File) {
        $item = $Content | New-Item -Name $Path -Path "${TestDriveName}\" -Type File -Force
    }

    if($PassThru) {
        return $item
    }
}

# SIG # Begin signature block
# MIIatwYJKoZIhvcNAQcCoIIaqDCCGqQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWD4e2q6p3Sr2P0u2LuAsr0ox
# RKGgghV6MIIEuzCCA6OgAwIBAgITMwAAAF3JyvZpIzdoUAAAAAAAXTANBgkqhkiG
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQCVOmC7i+isZty
# 7wp07VLyKoCjpDBgBgorBgEEAYI3AgEMMVIwUKAmgCQAVwBpAG4AZABvAHcAcwAg
# AFAAbwB3AGUAcgBTAGgAZQBsAGyhJoAkaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3Bvd2Vyc2hlbGwgMA0GCSqGSIb3DQEBAQUABIIBABwazq9mPQ08hKNoWdixcPdB
# chfRVbH3i1BLzxm+gG9O50VNCgM0w7sb/Rf333Z2pX4p/h7jcrh4EkXftH2Qxzhl
# nqIDNoCxfFYL7auMLVzfI+CaRmHFh+psckquols5GoWvO7AG/PSzUhI+iS06XZmt
# 56Nu/HdXJEXOLDrFsht7Z+z/Qvsie62sxPMK9kExhbgpNPVybr5e7pXz+hHMwaJI
# t1q/nf0aEwbiQv53xCNIq3jGjpB147muDcKwcFmJNkFHIDM8uHTttsCa3KR2k5ax
# nAGMiEF3ZLRS/m4F0AeM627c/rfhvT9UEfkd0REW5Cvr9WKFXxs3q5QhLvGrOsWh
# ggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBAhMzAAAAXcnK9mkjN2hQAAAAAABdMAkGBSsOAwIaBQCgXTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTAzMDUyMzU5
# MDhaMCMGCSqGSIb3DQEJBDEWBBRa2vtvWxpcC2HRfb5ep+YLYRt4ZDANBgkqhkiG
# 9w0BAQUFAASCAQCKWEVyftU2yJU/Xprwg7gDK+kKRvMsPVM+oMB4qbaO3ykb736G
# uRREijMQ05Q2s+wJv0Hs3SobOo7BuBlqj84OIdWw3kI1GXXnksDKZtEj2XV5nutr
# GRGhcqNaHzDoNOF2vhUGP/m3ESGHVD4O5UdGoqEfka/klSPk0yG1lc4eq5YDtqIE
# b8KLCJLqYQeFGIE/vPQxWpBQcJYHRn6nGcRIzFJTTb0lcV6gzLbGS5JBraYF3Cuy
# Zu5JjqQ/3oDSJe+QJ8m2WOQSRyk73jawN9eAqHFfm+jrjrZuisFQRXgG7AkdksTt
# zTx8MMc2m6P4is8k8EAQvu0ofh9VF8RHMkzZ
# SIG # End signature block
