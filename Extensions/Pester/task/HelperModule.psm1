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
        # Use the language parser to safely parse the hashtable string into a real hashtable.
        [System.Management.Automation.Language.Parser]::ParseInput($line, [Ref]$null, [Ref]$null).Find({
            $args[0] -is [System.Management.Automation.Language.HashtableAst]
        }, $false).SafeGetValue()
    }
}
