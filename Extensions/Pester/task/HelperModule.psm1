function Get-HashtableFromString
{
    param
    (
        [string]$line
    )

    # check for empty first
    If ([String]::IsNullOrEmpty($line)) {
        return @{}
    }

    # find first { and remove
    $firstBracket = $line.IndexOf("{")
    $lastBracket = $line.LastIndexOf("}")

    # not valid format
    if (($firstBracket -eq -1) -or ($lastBracket -eq -1))
    {
        return @{}
    }
        
    # strip the outside brackets
    $line = $line.substring($firstBracket+1, $lastBracket-$firstBracket-1).Trim()

     #find first param
    $nextSemiColon = $line.IndexOf(";")
    $nextEquals = $line.IndexOf("=")
    $nextAt = $line.IndexOf("@")
    $lastBracket = $line.IndexOf("}")
    $hashtable = @{}

    while ($nextEquals -gt -1 )
    {
        
        if ($nextSemiColon -eq -1)
        {
            # flags this is the last block
            $nextSemiColon = $line.length
        }

        $param = $line.substring(0, $nextEquals).trim()
        
        if (($nextAt -eq -1) -or ($nextAt -gt $nextSemiColon))
        {
            # we have a string value
            $value = $line.substring($nextEquals+1, $nextSemiColon-$nextEquals-1).trim().replace("`"","").replace("'","")
            if ($line.length -ne $nextSemiColon)
            {
                $line = $line.remove(0,$nextSemiColon+1)
            } else
            {
                $line = ""
            }
        } else
        {
            # we have a hashtable value
            $value = Get-HashtableFromString -line $line.substring($nextEquals+1, $lastBracket-$nextEquals).trim()
            $line = $line.remove(0,$lastBracket+1)
        }
        
        $hashtable.Add($param, $value)

        # and any leading ;
        if ($line.startswith(";"))
        {
            $line = $line.remove(0,1)
        }

        $nextSemiColon = $line.IndexOf(";")
        $nextEquals = $line.IndexOf("=")
        $nextAt = $line.IndexOf("@")
        $lastBracket = $line.IndexOf("}")
        
    }

    return $hashtable
}
