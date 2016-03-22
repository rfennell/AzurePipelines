if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Exit-CoverageAnalysis { }
    function Get-CoverageReport { }
    function Show-CoverageReport { }
    function Enter-CoverageAnalysis {
        param ( $CodeCoverage )

        if ($CodeCoverage) { Write-Error 'Code coverage analysis requires PowerShell 3.0 or later.' }
    }

    return
}

function Enter-CoverageAnalysis
{
    [CmdletBinding()]
    param (
        [object[]] $CodeCoverage,
        [object] $PesterState
    )

    $coverageInfo =
    foreach ($object in $CodeCoverage)
    {
        Get-CoverageInfoFromUserInput -InputObject $object
    }

    $PesterState.CommandCoverage = @(Get-CoverageBreakpoints -CoverageInfo $coverageInfo)
}

function Exit-CoverageAnalysis
{
    param ([object] $PesterState)

    Set-StrictMode -Off

    $breakpoints = @($PesterState.CommandCoverage.Breakpoint) -ne $null
    if ($breakpoints.Count -gt 0)
    {
        Remove-PSBreakpoint -Breakpoint $breakpoints
    }
}

function Get-CoverageInfoFromUserInput
{
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $unresolvedCoverageInfo = Get-CoverageInfoFromDictionary -Dictionary $InputObject
    }
    else
    {
        $unresolvedCoverageInfo = New-CoverageInfo -Path ([string]$InputObject)
    }

    Resolve-CoverageInfo -UnresolvedCoverageInfo $unresolvedCoverageInfo
}

function New-CoverageInfo
{
    param ([string] $Path, [string] $Function = $null, [int] $StartLine = 0, [int] $EndLine = 0)

    return [pscustomobject]@{
        Path = $Path
        Function = $Function
        StartLine = $StartLine
        EndLine = $EndLine
    }
}

function Get-CoverageInfoFromDictionary
{
    param ([System.Collections.IDictionary] $Dictionary)

    [string] $path = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Path', 'p'
    if ([string]::IsNullOrEmpty($path))
    {
        throw "Coverage value '$Dictionary' is missing required Path key."
    }

    $startLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'StartLine', 'Start', 's'
    $endLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'EndLine', 'End', 'e'
    [string] $function = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Function', 'f'

    $startLine = Convert-UnknownValueToInt -Value $startLine -DefaultValue 0
    $endLine = Convert-UnknownValueToInt -Value $endLine -DefaultValue 0

    return New-CoverageInfo -Path $path -StartLine $startLine -EndLine $endLine -Function $function
}

function Convert-UnknownValueToInt
{
    param ([object] $Value, [int] $DefaultValue = 0)

    try
    {
        return [int] $Value
    }
    catch
    {
        return $DefaultValue
    }
}

function Resolve-CoverageInfo
{
    param ([psobject] $UnresolvedCoverageInfo)

    $path = $UnresolvedCoverageInfo.Path

    try
    {
        $resolvedPaths = Resolve-Path -Path $path -ErrorAction Stop
    }
    catch
    {
        Write-Error "Could not resolve coverage path '$path': $($_.Exception.Message)"
        return
    }

    $filePaths =
    foreach ($resolvedPath in $resolvedPaths)
    {
        $item = Get-Item -LiteralPath $resolvedPath
        if ($item -is [System.IO.FileInfo] -and ('.ps1','.psm1') -contains $item.Extension)
        {
            $item.FullName
        }
        elseif (-not $item.PsIsContainer)
        {
            Write-Warning "CodeCoverage path '$path' resolved to a non-PowerShell file '$($item.FullName)'; this path will not be part of the coverage report."
        }
    }

    $params = @{
        StartLine = $UnresolvedCoverageInfo.StartLine
        EndLine = $UnresolvedCoverageInfo.EndLine
        Function = $UnresolvedCoverageInfo.Function
    }

    foreach ($filePath in $filePaths)
    {
        $params['Path'] = $filePath
        New-CoverageInfo @params
    }
}

function Get-CoverageBreakpoints
{
    [CmdletBinding()]
    param (
        [object[]] $CoverageInfo
    )

    $fileGroups = @($CoverageInfo | Group-Object -Property Path)
    foreach ($fileGroup in $fileGroups)
    {
        Write-Verbose "Initializing code coverage analysis for file '$($fileGroup.Name)'"
        $totalCommands = 0
        $analyzedCommands = 0

        :commandLoop
        foreach ($command in Get-CommandsInFile -Path $fileGroup.Name)
        {
            $totalCommands++

            foreach ($coverageInfoObject in $fileGroup.Group)
            {
                if (Test-CoverageOverlapsCommand -CoverageInfo $coverageInfoObject -Command $command)
                {
                    $analyzedCommands++
                    New-CoverageBreakpoint -Command $command
                    continue commandLoop
                }
            }
        }

        Write-Verbose "Analyzing $analyzedCommands of $totalCommands commands in file '$($fileGroup.Name)' for code coverage"
    }
}

function Get-CommandsInFile
{
    param ([string] $Path)

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $errors)

    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        # In PowerShell 5.0, dynamic keywords for DSC configurations are represented by the DynamicKeywordStatementAst
        # class.  They still trigger breakpoints, but are not a child class of CommandBaseAst anymore.

        $predicate = {
            $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -or
            $args[0] -is [System.Management.Automation.Language.CommandBaseAst]
        }
    }
    else
    {
        $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
    }

    $searchNestedScriptBlocks = $true
    $ast.FindAll($predicate, $searchNestedScriptBlocks)
}

function Test-CoverageOverlapsCommand
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    if ($CoverageInfo.Function)
    {
        Test-CommandInsideFunction -Command $Command -Function $CoverageInfo.Function
    }
    else
    {
        Test-CoverageOverlapsCommandByLineNumber @PSBoundParameters
    }

}

function Test-CommandInsideFunction
{
    param ([System.Management.Automation.Language.Ast] $Command, [string] $Function)

    for ($ast = $Command; $null -ne $ast; $ast = $ast.Parent)
    {
        $functionAst = $ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
        if ($null -ne $functionAst -and $functionAst.Name -like $Function)
        {
            return $true
        }
    }

    return $false
}

function Test-CoverageOverlapsCommandByLineNumber
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    $commandStart = $Command.Extent.StartLineNumber
    $commandEnd = $Command.Extent.EndLineNumber
    $coverStart = $CoverageInfo.StartLine
    $coverEnd = $CoverageInfo.EndLine

    # An EndLine value of 0 means to cover the entire rest of the file from StartLine
    # (which may also be 0)
    if ($coverEnd -le 0) { $coverEnd = [int]::MaxValue }

    return (Test-RangeContainsValue -Value $commandStart -Min $coverStart -Max $coverEnd) -or
           (Test-RangeContainsValue -Value $commandEnd -Min $coverStart -Max $coverEnd)
}

function Test-RangeContainsValue
{
    param ([int] $Value, [int] $Min, [int] $Max)
    return $Value -ge $Min -and $Value -le $Max
}

function New-CoverageBreakpoint
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (IsIgnoredCommand -Command $Command) { return }

    $params = @{
        Script = $Command.Extent.File
        Line   = $Command.Extent.StartLineNumber
        Column = $Command.Extent.StartColumnNumber
        Action = { }
    }

    $breakpoint = Set-PSBreakpoint @params

    [pscustomobject] @{
        File       = $Command.Extent.File
        Function   = Get-ParentFunctionName -Ast $Command
        Line       = $Command.Extent.StartLineNumber
        Command    = Get-CoverageCommandText -Ast $Command
        Breakpoint = $breakpoint
    }
}

function IsIgnoredCommand
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (-not $Command.Extent.File)
    {
        # This can happen if the script contains "configuration" or any similarly implemented
        # dynamic keyword.  PowerShell modifies the script code and reparses it in memory, leading
        # to AST elements with no File in their Extent.
        return $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 4)
    {
        if ($Command.Extent.Text -eq 'Configuration')
        {
            # More DSC voodoo.  Calls to "configuration" generate breakpoints, but their HitCount
            # stays zero (even though they are executed.)  For now, ignore them, unless we can come
            # up with a better solution.
            return $true
        }

        if (IsChildOfHashtableDynamicKeyword -Command $Command)
        {
            # The lines inside DSC resource declarations don't trigger their breakpooints when executed,
            # just like the "configuration" keyword itself.  I don't know why, at this point, but just like
            # configuration, we'll ignore it so it doesn't clutter up the coverage analysis with useless junk.
            return $true
        }
    }

    if (IsClosingLoopCondition -Command $Command)
    {
        # For some reason, the closing expressions of do/while and do/until loops don't trigger their breakpoints.
        # To avoid useless clutter, we'll ignore those lines as well.
        return $true
    }

    return $false
}

function IsChildOfHashtableDynamicKeyword
{
    param ([System.Management.Automation.Language.Ast] $Command)

    for ($ast = $Command.Parent; $null -ne $ast; $ast = $ast.Parent)
    {
        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            # The ast behaves differently for DSC resources with version 5+.  There's a new DynamicKeywordStatementAst class,
            # and they no longer are represented by CommandAst objects.

            if ($ast -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -and
                $ast.CommandElements[-1] -is [System.Management.Automation.Language.HashtableAst])
            {
                return $true
            }
        }
        else
        {
            if ($ast -is [System.Management.Automation.Language.CommandAst] -and
                $null -ne $ast.DefiningKeyword -and
                $ast.DefiningKeyword.BodyMode -eq [System.Management.Automation.Language.DynamicKeywordBodyMode]::Hashtable)
            {
                return $true
            }
        }
    }

    return $false
}

function IsClosingLoopCondition
{
    param ([System.Management.Automation.Language.Ast] $Command)

    $ast = $Command

    while ($null -ne $ast.Parent)
    {
        if (($ast.Parent -is [System.Management.Automation.Language.DoWhileStatementAst] -or
            $ast.Parent -is [System.Management.Automation.Language.DoUntilStatementAst]) -and
            $ast.Parent.Condition -eq $ast)
        {
            return $true
        }

        $ast = $ast.Parent
    }

    return $false
}

function Get-ParentFunctionName
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $Ast.Parent

    while ($null -ne $parent -and $parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst])
    {
        $parent = $parent.Parent
    }

    if ($null -eq $parent)
    {
        return ''
    }
    else
    {
        return $parent.Name
    }
}

function Get-CoverageCommandText
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $reportParentExtentTypes = @(
        [System.Management.Automation.Language.ReturnStatementAst]
        [System.Management.Automation.Language.ThrowStatementAst]
        [System.Management.Automation.Language.AssignmentStatementAst]
        [System.Management.Automation.Language.IfStatementAst]
    )

    $parent = Get-ParentNonPipelineAst -Ast $Ast

    if ($null -ne $parent)
    {
        if ($parent -is [System.Management.Automation.Language.HashtableAst])
        {
            return Get-KeyValuePairText -HashtableAst $parent -ChildAst $Ast
        }
        elseif ($reportParentExtentTypes -contains $parent.GetType())
        {
            return $parent.Extent.Text
        }
    }

    return $Ast.Extent.Text
}

function Get-ParentNonPipelineAst
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $null
    if ($null -ne $Ast) { $parent = $Ast.Parent }

    while ($parent -is [System.Management.Automation.Language.PipelineAst])
    {
        $parent = $parent.Parent
    }

    return $parent
}

function Get-KeyValuePairText
{
    param (
        [System.Management.Automation.Language.HashtableAst] $HashtableAst,
        [System.Management.Automation.Language.Ast] $ChildAst
    )

    Set-StrictMode -Off

    foreach ($keyValuePair in $HashtableAst.KeyValuePairs)
    {
        if ($keyValuePair.Item2.PipelineElements -contains $ChildAst)
        {
            return '{0} = {1}' -f $keyValuePair.Item1.Extent.Text, $keyValuePair.Item2.Extent.Text
        }
    }

    # This shouldn't happen, but just in case, default to the old output of just the expression.
    return $ChildAst.Extent.Text
}

function Get-CoverageMissedCommands
{
    param ([object[]] $CommandCoverage)
    $CommandCoverage | Where-Object { $_.Breakpoint.HitCount -eq 0 }
}

function Get-CoverageReport
{
    param ([object] $PesterState)

    $totalCommandCount = $PesterState.CommandCoverage.Count

    $missedCommands = @(Get-CoverageMissedCommands -CommandCoverage $PesterState.CommandCoverage | Select-Object File, Line, Function, Command)
    $analyzedFiles = @($PesterState.CommandCoverage | Select-Object -ExpandProperty File -Unique)
    $fileCount = $analyzedFiles.Count

    $executedCommandCount = $totalCommandCount - $missedCommands.Count

    [pscustomobject] @{
        NumberOfCommandsAnalyzed = $totalCommandCount
        NumberOfFilesAnalyzed    = $fileCount
        NumberOfCommandsExecuted = $executedCommandCount
        NumberOfCommandsMissed   = $missedCommands.Count
        MissedCommands           = $missedCommands
        AnalyzedFiles            = $analyzedFiles
    }
}

function Show-CoverageReport
{
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $commandPlural = $filePlural = ''
    if ($totalCommandCount -gt 1) { $commandPlural = 's' }
    if ($fileCount -gt 1) { $filePlural = 's' }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | Select-Object -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    Write-Screen ''
    Write-Screen 'Code coverage report:'
    Write-Screen "Covered $executedPercent of $totalCommandCount analyzed command$commandPlural in $fileCount file$filePlural."

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        Write-Screen ''
        Write-Screen 'Missed commands:'
        $report | Format-Table -AutoSize | Out-String | Write-Screen
    }
}

function Get-CommonParentPath
{
    param ([string[]] $Path)

    $pathsToTest = @( $Path | Select-Object -Unique )

    if ($pathsToTest.Count -gt 0)
    {
        $parentPath = Split-Path -Path $pathsToTest[0] -Parent

        while ($parentPath.Length -gt 0)
        {
            $nonMatches = $pathsToTest -notmatch "^$([regex]::Escape($parentPath))"

            if ($nonMatches.Count -eq 0)
            {
                return $parentPath
            }
            else
            {
                $parentPath = Split-Path -Path $parentPath -Parent
            }
        }
    }

    return [string]::Empty
}

function Get-RelativePath
{
    param ( [string] $Path, [string] $RelativeTo )
    return $Path -replace "^$([regex]::Escape($RelativeTo))\\?"
}

# SIG # Begin signature block
# MIIatwYJKoZIhvcNAQcCoIIaqDCCGqQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGTRxL6Bdvu7E8RBo3iyL9D32
# KQygghV6MIIEuzCCA6OgAwIBAgITMwAAAF3JyvZpIzdoUAAAAAAAXTANBgkqhkiG
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRXcCzW+aalgvvn
# zvuoGLzGOzzhEDBgBgorBgEEAYI3AgEMMVIwUKAmgCQAVwBpAG4AZABvAHcAcwAg
# AFAAbwB3AGUAcgBTAGgAZQBsAGyhJoAkaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3Bvd2Vyc2hlbGwgMA0GCSqGSIb3DQEBAQUABIIBAFlZMgdfrCiqQziG6eRT6Bbv
# hso9FQTOUoEOBwzu2ZUvAiQegZuDin/bI9qwaPNq+va2lbuvWCcSUk1k8/a5l7VH
# AZiklDPEjH5lbpV0XiwJ2ZIM5Vl91GHYGPoAyZDMULNyloLo3RYiUwqyhZhPknQc
# rI1sQgg7NOQ51X+TrO5LOlFlmxyvd5nSEWJ8PDRX6aqMsjYoNzfpvbh+CQXA1yoF
# yDbS/DyBs8ywKUtmQSkH4x97xRFelCNYb6HuncUXiaUebZtnhpLkRUuE7o3PRs5U
# kQEm5suESIbxD8c+w2syX+gvnR3uQanzcKCDdd8+aZeH+kR1pFZwjCn8yXTBkVCh
# ggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBAhMzAAAAXcnK9mkjN2hQAAAAAABdMAkGBSsOAwIaBQCgXTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTAzMDUyMzU5
# MDhaMCMGCSqGSIb3DQEJBDEWBBT974H6V2uum0xF1Ae7dUurIg+fPTANBgkqhkiG
# 9w0BAQUFAASCAQBMqTqyd7baQQ90hxnZWJcfozrL6psDC7wiZ+ApejfZHIoPGo4V
# jFx+2rEfsptjyOsZAsyHsYIQdi5cORt61sLczb5DamXFtUNrestARoWogJ5IoFsm
# /7jCBoF+WhR+93afV5ohfmeEPJXOYSknfPxh7V90nGTJPpa2GCNSuKaiNMcbAhDp
# 3XC2cm/APzvr3QXy47qRWSHN66sofbTygdkFYUVZuMFTNEZmJkcT0Z7iueTS6EE7
# ItTIrX3FyiI+LjijFJmp3h3RiuB06zBKJZ2L9P/T7BAjecsOYIv0V2eGjWXOqleY
# UA8ljBnh0JBzbK0MLNzspmNfNiQAPlKWuzB7
# SIG # End signature block
