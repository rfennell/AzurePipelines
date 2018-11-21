function Get-HashtableFromString
{
    param
    (
        [string]$lineInput
    )

    # check for empty first
    If ([String]::IsNullOrEmpty($lineInput.trim(';'))) {
        return @{}
    }

    Foreach ($line in ($lineInput -split '(?<=}\s*),')) {
        $Hashtable = [System.Management.Automation.Language.Parser]::ParseInput($line, [Ref]$null, [Ref]$null).Find({
            $args[0] -is [System.Management.Automation.Language.HashtableAst]
        }, $false)

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            # Use the language parser to safely parse the hashtable string into a real hashtable.
            $Hashtable.SafeGetValue()
        }
        else {
            Write-Warning -Message "PowerShell Version lower than 5 detected. Performing Unsafe hashtable conversion. Please update to version 5 or above when possible for safe conversion of hashtable."
            Invoke-Expression -Command $Hashtable.Extent
        }
    }
}
