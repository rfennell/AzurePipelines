#Region '.\Header\00. param.ps1' 0
param(
   $Converters = @{}
)

$ModuleManifestExtension = ".psd1"
#EndRegion '.\Header\00. param.ps1' 6
#Region '.\Header\01. IMetadataSerializable.ps1' 0
Add-Type -TypeDefinition @'
public interface IPsMetadataSerializable {
    string ToPsMetadata();
    void FromPsMetadata(string Metadata);
}
'@
#EndRegion '.\Header\01. IMetadataSerializable.ps1' 7
#Region '.\Private\FindHashKeyValue.ps1' 0
function FindHashKeyValue {
    [CmdletBinding()]
    param(
        $SearchPath,
        $Ast,
        [string[]]
        $CurrentPath = @()
    )
    # Write-Debug "FindHashKeyValue: $SearchPath -eq $($CurrentPath -Join '.')"
    if ($SearchPath -eq ($CurrentPath -Join '.') -or $SearchPath -eq $CurrentPath[-1]) {
        return $Ast |
            Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force |
            Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }

    if ($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst] ) {
        $KeyValue = $Ast.PipelineElements.Expression
        foreach ($KV in $KeyValue.KeyValuePairs) {
            $result = FindHashKeyValue $SearchPath -Ast $KV.Item2 -CurrentPath ($CurrentPath + $KV.Item1.Value)
            if ($null -ne $result) {
                $result
            }
        }
    }
}
#EndRegion '.\Private\FindHashKeyValue.ps1' 26
#Region '.\Private\ThrowError.ps1' 0
# Utility to throw an errorrecord
function ThrowError {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidOverwritingBuiltInCmdlets", "")]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName = "ExistingException", Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = "NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = "NewException", Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType = "System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName = "NewException", Position = 3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, ParameterSetName = "ExistingException", Position = 10)]
        [Parameter(Mandatory = $true, ParameterSetName = "NewException", Position = 10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, ParameterSetName = "ExistingException", Position = 11)]
        [Parameter(Mandatory = $true, ParameterSetName = "NewException", Position = 11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName = "Rethrow", Position = 1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if (!$ErrorRecord) {
            if ($PSCmdlet.ParameterSetName -eq "NewException") {
                if ($Exception) {
                    $Exception = New-Object $ExceptionType $Message, $Exception
                } else {
                    $Exception = New-Object $ExceptionType $Message
                }
            }
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $Category, $TargetObject
        }
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }
}
#EndRegion '.\Private\ThrowError.ps1' 60
#Region '.\Private\WriteError.ps1' 0
# Utility to throw an errorrecord
function WriteError {
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName = "ExistingException", Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = "NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = "NewException", Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType = "System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName = "NewException", Position = 3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, Position = 10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, Position = 11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName = "Rethrow", Position = 1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if (!$ErrorRecord) {
            if ($PSCmdlet.ParameterSetName -eq "NewException") {
                if ($Exception) {
                    $Exception = New-Object $ExceptionType $Message, $Exception
                } else {
                    $Exception = New-Object $ExceptionType $Message
                }
            }
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $Category, $TargetObject
        }
        $Cmdlet.WriteError($errorRecord)
    }
}
#EndRegion '.\Private\WriteError.ps1' 57
#Region '.\Public\Add-MetadataConverter.ps1' 0
function Add-MetadataConverter {
    <#
      .Synopsis
         Add a converter functions for serialization and deserialization to metadata
      .Description
         Add-MetadataConverter allows you to map:
         * a type to a scriptblock which can serialize that type to metadata (psd1)
         * define a name and scriptblock as a function which will be whitelisted in metadata (for ConvertFrom-Metadata and Import-Metadata)

         The idea is to give you a way to extend the serialization capabilities if you really need to.
      .Example
         Add-MetadataCOnverter @{ [bool] = { if($_) { '$True' } else { '$False' } } }

         Shows a simple example of mapping bool to a scriptblock that serializes it in a way that's inherently parseable by PowerShell.  This exact converter is already built-in to the Metadata module, so you don't need to add it.

      .Example
         Add-MetadataConverter @{
            [Uri] = { "Uri '$_' " }
            "Uri" = {
               param([string]$Value)
               [Uri]$Value
            }
         }

         Shows how to map a function for serializing Uri objects as strings with a Uri function that just casts them. Normally you wouldn't need to do that for Uri, since they output strings natively, and it's perfectly logical to store Uris as strings and only cast them when you really need to.

      .Example
         Add-MetadataConverter @{
            [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
            "DateTimeOffset" = {param($ticks,$offset) [DateTimeOffset]::new( $ticks, $offset )}
         }

         Shows how to change the DateTimeOffset serialization.

         By default, DateTimeOffset values are (de)serialized using the 'o' RoundTrips formatting
         e.g.: [DateTimeOffset]::Now.ToString('o')

   #>
    [CmdletBinding()]
    param(
        # A hashtable of types to serializer scriptblocks, or function names to scriptblock definitions
        [Parameter(Mandatory = $True)]
        [hashtable]$Converters
    )

    if ($Converters.Count) {
        switch ($Converters.Keys.GetEnumerator()) {
            {$Converters[$_] -isnot [ScriptBlock]} {
                WriteError -ExceptionType System.ArgumentExceptionn `
                    -Message "Ignoring $_ converter, the value must be ScriptBlock!" `
                    -ErrorId "NotAScriptBlock,Metadata\Add-MetadataConverter" `
                    -Category "InvalidArgument"
                continue
            }

            {$_ -is [String]} {
                # Write-Debug "Storing deserialization function: $_"
                Set-Content "function:script:$_" $Converters[$_]
                # We need to store the function in MetadataDeserializers
                $script:MetadataDeserializers[$_] = $Converters[$_]
                continue
            }

            {$_ -is [Type]} {
                # Write-Debug "Adding serializer for $($_.FullName)"
                $script:MetadataSerializers[$_] = $Converters[$_]
                continue
            }
            default {
                WriteError -ExceptionType System.ArgumentExceptionn `
                    -Message "Unsupported key type in Converters: $_ is $($_.GetType())" `
                    -ErrorId "InvalidKeyType,Metadata\Add-MetadataConverter" `
                    -Category "InvalidArgument"
            }
        }
    }
}
#EndRegion '.\Public\Add-MetadataConverter.ps1' 78
#Region '.\Public\ConvertFrom-Metadata.ps1' 0
function ConvertFrom-Metadata {
    <#
    .Synopsis
        Deserializes objects from PowerShell Data language (PSD1)
    .Description
        Converts psd1 notation to actual objects, and supports passing in additional converters
        in addition to using the built-in registered converters (see Add-MetadataConverter).

        NOTE: Any Converters that are passed in are temporarily added as though passed Add-MetadataConverter
    .Example
        ConvertFrom-Metadata 'PSObject @{ Name = PSObject @{ First = "Joel"; Last = "Bennett" }; Id = 1; }'

        Id Name
        -- ----
        1 @{Last=Bennett; First=Joel}

        Convert the example string into a real PSObject using the built-in object serializer.
    .Example
        $data = ConvertFrom-Metadata .\Configuration.psd1 -Ordered

        Convert a module manifest into a hashtable of properties for introspection, preserving the order in the file
    .Example
        ConvertFrom-Metadata ("DateTimeOffset 635968680686066846 -05:00:00") -Converters @{
        "DateTimeOffset" = {
            param($ticks,$offset)
            [DateTimeOffset]::new( $ticks, $offset )
        }
        }

        Shows how to temporarily add a "ValidCommand" called "DateTimeOffset" to support extra data types in the metadata.

        See also the third example on ConvertTo-Metadata and Add-MetadataConverter
    #>
    [CmdletBinding()]
    param(
        # The metadata text (or a path to a metadata file)
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        $InputObject,

        # A hashtable of MetadataConverters (same as with Add-MetadataConverter)
        [Hashtable]$Converters = @{},

        # The PSScriptRoot which the metadata should be evaluated from.
        # You do not normally need to pass this, and it has no effect unless
        # you're referencing $ScriptRoot in your metadata
        $ScriptRoot = "$PSScriptRoot",

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in metadata
        # BEWARE: This exposes the value of these variables in your context to the caller
        # You ware reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables,

        # You should not pass this.
        # The PSVariable parameter is for preserving variable scope within the Metadata commands
        [System.Management.Automation.PSVariableIntrinsics]$PSVariable
    )
    begin {
        $OriginalMetadataSerializers = $Script:MetadataSerializers.Clone()
        $OriginalMetadataDeserializers = $Script:MetadataDeserializers.Clone()
        Add-MetadataConverter $Converters
        [string[]]$ValidCommands = @(
            "ConvertFrom-StringData", "Join-Path", "Split-Path", "ConvertTo-SecureString"
        ) + @($MetadataDeserializers.Keys)
        [string[]]$ValidVariables = $AllowedVariables + @(
            "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot", "PSCulture", "PSUICulture", "True", "False", "Null")

        if (!$PSVariable) {
            $PSVariable = $PSCmdlet.SessionState.PSVariable
        }
    }
    end {
        $Script:MetadataSerializers = $OriginalMetadataSerializers.Clone()
        $Script:MetadataDeserializers = $OriginalMetadataDeserializers.Clone()
    }
    process {
        $ErrorActionPreference = "Stop"
        $Tokens = $Null; $ParseErrors = $Null

        if (Test-PSVersion -lt "3.0") {
            # Write-Debug "ConvertFrom-Metadata: Using Import-LocalizedData to support PowerShell $($PSVersionTable.PSVersion)"
            # Write-Debug "ConvertFrom-Metadata: $InputObject"
            if (!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
                $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
                Set-Content -Encoding UTF8 -Path $Path $InputObject
                $InputObject = $Path
            } elseif (!"$InputObject".EndsWith($ModuleManifestExtension)) {
                $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
                Copy-Item "$InputObject" "$Path"
                $InputObject = $Path
            }
            $Result = $null
            Import-LocalizedData -BindingVariable Result -BaseDirectory (Split-Path $InputObject) -FileName (Split-Path $InputObject -Leaf) -SupportedCommand $ValidCommands
            return $Result
        }

        if (Test-Path $InputObject -ErrorAction SilentlyContinue) {
            # Write-Debug "ConvertFrom-Metadata: Using ParseInput to support PowerShell $($PSVersionTable.PSVersion)"
            # ParseFile on PS5 (and older) doesn't handle utf8 encoding properly (treats it as ASCII)
            # Sometimes, that causes an avoidable error. So I'm avoiding it, if I can:
            $Path = Convert-Path $InputObject
            if (!$PSBoundParameters.ContainsKey('ScriptRoot')) {
                $ScriptRoot = Split-Path $Path
            }
            $Content = (Get-Content -Path $InputObject -Encoding UTF8)
            # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
            $Content = $Content -join "`n" -replace "# SIG # Begin signature block(?s:.*)"
            try {
                # But older versions of PowerShell, this will throw a MethodException because the overload is missing
                $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, $Path, [ref]$Tokens, [ref]$ParseErrors)
            } catch [System.Management.Automation.MethodException] {
                # Write-Debug "ConvertFrom-Metadata: Using ParseFile as a backup for PowerShell $($PSVersionTable.PSVersion)"
                $AST = [System.Management.Automation.Language.Parser]::ParseFile( $Path, [ref]$Tokens, [ref]$ParseErrors)

                # If we got parse errors on older versions of PowerShell, test to see if the error is just encoding
                if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
                    $StillErrors = $null
                    $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$StillErrors)
                    # If we didn't get errors, clear the errors
                    # Otherwise, we want to use the original errors with the path in them
                    if ($null -eq $StillErrors -or $StillErrors.Count -eq 0) {
                        $ParseErrors = $StillErrors
                    }
                }
            }
        } else {
            # Write-Debug "ConvertFrom-Metadata: Using ParseInput with loose metadata: $InputObject"
            if (!$PSBoundParameters.ContainsKey('ScriptRoot')) {
                $ScriptRoot = $PoshCodeModuleRoot
            }

            $OFS = "`n"
            # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
            $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
        }

        if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
            ThrowError -Exception (New-Object System.Management.Automation.ParseException (, [System.Management.Automation.Language.ParseError[]]$ParseErrors)) -ErrorId "Metadata Error" -Category "ParserError" -TargetObject $InputObject
        }

        # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
        $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -ExpandProperty NestedTokens

        # Write-Debug "ConvertFrom-Metadata: Searching $($Tokens.Count) variables for: $($ValidVariables -join ', '))"
        # Work around PowerShell rules about magic variables
        # Change all the "ValidVariables" to use names like __Metadata__OriginalName__
        # Later, we'll try to make sure these are all set!
        if (($UsedVariables = $Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -in $ValidVariables) })) {
            # Write-Debug "ConvertFrom-Metadata: Replacing $($UsedVariables.Name -join ', ')"
            if (($extents = @( $UsedVariables | ForEach-Object { $_.Extent | Add-Member NoteProperty Name $_.Name -PassThru } ))) {
                $ScriptContent = $Ast.ToString()
                # Write-Debug "ConvertFrom-Metadata: Replacing $($UsedVariables.Count) variables in metadata: $ScriptContent"
                for ($r = $extents.count - 1; $r -ge 0; $r--) {
                    $VariableExtent = $extents[$r]
                    $VariableName = if ($VariableExtent.Name -eq "PSScriptRoot") {
                        '${__Metadata__ScriptRoot__}'
                    } else {
                        '${__Metadata__' + $VariableExtent.Name + '__}'
                    }
                    $ScriptContent = $ScriptContent.Remove( $VariableExtent.StartOffset,
                                                            ($VariableExtent.EndOffset - $VariableExtent.StartOffset)
                                                            ).Insert($VariableExtent.StartOffset, $VariableName)
                }
            }
            Write-Debug "ConvertFrom-Metadata: Replaced $($UsedVariables.Name -join ' and ') in metadata: $ScriptContent"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
        }

        $Script = $AST.GetScriptBlock()
        try {
            [string[]]$PrivateVariables = $ValidVariables -replace "^.*$", '__Metadata__$0__'
            Write-Debug "ConvertFrom-Metadata: Validating metadata: $Script against $PrivateVariables"
            $Script.CheckRestrictedLanguage( $ValidCommands, $PrivateVariables, $true )
        } catch {
            ThrowError -Exception $_.Exception.InnerException -ErrorId "Metadata Error" -Category "InvalidData" -TargetObject $Script
        }

        # Set the __Metadata__ValidVariables__ in our scope but not for constant variables:
        $ReplacementVariables = $ValidVariables | Where-Object { $_ -notin "PSCulture", "PSUICulture", "True", "False", "Null" }
        foreach ($name in $ReplacementVariables) {
            # We already read the script root from the calling scope ...
            if ($Name -in "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot") {
                $Value = $ScriptRoot
            } elseif (!($Value = $PSVariable.GetValue($Name))) {
                $Value = "`${$Name}"
            }
            Write-Debug "ConvertFrom-Metadata: Setting __Metadata__${Name}__ = $Value"
            Set-Variable "__Metadata__${Name}__" $Value
        }

        if ($Ordered -and (Test-PSVersion -gt "3.0")) {
            # Write-Debug "ConvertFrom-Metadata: Supporting [Ordered] on PowerShell $($PSVersionTable.PSVersion)"
            # Make all the hashtables ordered, so that the output objects make more sense to humans...
            if ($Tokens | Where-Object { "AtCurly" -eq $_.Kind }) {
                $ScriptContent = $AST.ToString()
                $Hashtables = $AST.FindAll( {$args[0] -is [System.Management.Automation.Language.HashtableAst] -and ("ordered" -ne $args[0].Parent.Type.TypeName)}, $Recurse)
                $Hashtables = $Hashtables | ForEach-Object {
                    New-Object PSObject -Property @{Type = "([ordered]"; Position = $_.Extent.StartOffset}
                    New-Object PSObject -Property @{Type = ")"; Position = $_.Extent.EndOffset}
                } | Sort-Object Position -Descending
                foreach ($point in $Hashtables) {
                    $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
                }

                $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
                $Script = $AST.GetScriptBlock()
            }
        }
        # Write-Debug "ConvertFrom-Metadata: Metadata: $Script"
        # Write-Debug "ConvertFrom-Metadata: Switching to RestrictedLanguage mode"
        $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

        try {
            $Script.InvokeReturnAsIs(@())
        } finally {
            $ExecutionContext.SessionState.LanguageMode = $Mode
            # Write-Debug "ConvertFrom-Metadata: Switching to $Mode mode"
        }
    }
}
#EndRegion '.\Public\ConvertFrom-Metadata.ps1' 226
#Region '.\Public\ConvertTo-Metadata.ps1' 0
function ConvertTo-Metadata {
    #.Synopsis
    #  Serializes objects to PowerShell Data language (PSD1)
    #.Description
    #  Converts objects to a texual representation that is valid in PSD1,
    #  using the built-in registered converters (see Add-MetadataConverter).
    #
    #  NOTE: Any Converters that are passed in are temporarily added as though passed Add-MetadataConverter
    #.Example
    #  $Name = @{ First = "Joel"; Last = "Bennett" }
    #  @{ Name = $Name; Id = 1; } | ConvertTo-Metadata
    #
    #  @{
    #    Id = 1
    #    Name = @{
    #      Last = 'Bennett'
    #      First = 'Joel'
    #    }
    #  }
    #
    #  Convert input objects into a formatted string suitable for storing in a psd1 file.
    #.Example
    #  Get-ChildItem -File | Select-Object FullName, *Utc, Length | ConvertTo-Metadata
    #
    #  Convert complex custom types to dynamic PSObjects using Select-Object.
    #
    #  ConvertTo-Metadata understands PSObjects automatically, so this allows us to proceed
    #  without a custom serializer for File objects, but the serialized data
    #  will not be a FileInfo or a DirectoryInfo, just a custom PSObject
    #.Example
    #  ConvertTo-Metadata ([DateTimeOffset]::Now) -Converters @{
    #     [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
    #  }
    #
    #  Shows how to temporarily add a MetadataConverter to convert a specific type while serializing the current DateTimeOffset.
    #  Note that this serialization would require a "DateTimeOffset" function to exist in order to deserialize properly.
    #
    #  See also the third example on ConvertFrom-Metadata and Add-MetadataConverter.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to metadata
        [Parameter(ValueFromPipeline = $True)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        # Additional converters
        [Hashtable]$Converters = @{}
    )
    begin {
        $t = "  "
        $Script:OriginalMetadataSerializers = $Script:MetadataSerializers.Clone()
        $Script:OriginalMetadataDeserializers = $Script:MetadataDeserializers.Clone()
        Add-MetadataConverter $Converters
    }
    end {
        $Script:MetadataSerializers = $Script:OriginalMetadataSerializers.Clone()
        $Script:MetadataDeserializers = $Script:OriginalMetadataDeserializers.Clone()
    }
    process {
        if ($Null -eq $InputObject) {
            '""'
        } elseif ($InputObject -is [IPsMetadataSerializable] -or ($InputObject.ToPsMetadata -as [Func[String]] -and $InputObject.FromPsMetasta -as [Action[String]])) {
            "(FromPsMetadata {0} @'`n{1}`n'@)" -f $InputObject.GetType().FullName, $InputObject.ToMetadata()
        } elseif ( $InputObject -is [Int16] -or
                   $InputObject -is [Int32] -or
                   $InputObject -is [Int64] -or
                   $InputObject -is [Double] -or
                   $InputObject -is [Decimal] -or
                   $InputObject -is [Byte] ) {
            "$InputObject"
        } elseif ($InputObject -is [String]) {
            "'{0}'" -f $InputObject.ToString().Replace("'", "''")
        } elseif ($InputObject -is [Collections.IDictionary]) {
            "@{{`n$t{0}`n}}" -f ($(
                    ForEach ($key in @($InputObject.Keys)) {
                        if ("$key" -match '^([A-Za-z_]\w*|-?\d+\.?\d*)$') {
                            "$key = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        } else {
                            "'$key' = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        }
                    }) -split "`n" -join "`n$t")
        } elseif ($InputObject -is [System.Collections.IEnumerable]) {
            "@($($(ForEach($item in @($InputObject)) { $item | ConvertTo-Metadata -AsHashtable:$AsHashtable}) -join ","))"
        } elseif($InputObject -is [System.Management.Automation.ScriptBlock]) {
            # Escape single-quotes by doubling them:
            "(ScriptBlock '{0}')" -f ("$_" -replace "'", "''")
        } elseif ($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
            # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
            $(if ($AsHashtable) {
                    "@{{`n$t{0}`n}}"
                } else {
                    "(PSObject @{{`n$t{0}`n}} -TypeName '$($InputObject.PSTypeNames -join "','")')"
                }) -f ($(
                    ForEach ($key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name) {
                        if ("$key" -match '^([A-Za-z_]\w*|-?\d+\.?\d*)$') {
                            "$key = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        } else {
                            "'$key' = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        }
                    }
                ) -split "`n" -join "`n$t")
        } elseif ($MetadataSerializers.ContainsKey($InputObject.GetType())) {
            $Str = ForEach-Object $MetadataSerializers.($InputObject.GetType()) -InputObject $InputObject

            [bool]$IsCommand = & {
                $ErrorActionPreference = "Stop"
                $Tokens = $Null; $ParseErrors = $Null
                $AST = [System.Management.Automation.Language.Parser]::ParseInput( $Str, [ref]$Tokens, [ref]$ParseErrors)
                $Null -ne $Ast.Find( {$args[0] -is [System.Management.Automation.Language.CommandAst]}, $false)
            }

            if ($IsCommand) { "($Str)" } else { $Str }
        } else {
            Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
            "'{0}'" -f $InputObject.ToString().Replace("'", "`'`'")
        }
    }
}
#EndRegion '.\Public\ConvertTo-Metadata.ps1' 122
#Region '.\Public\Export-Metadata.ps1' 0
function Export-Metadata {
    <#
        .Synopsis
            Creates a metadata file from a simple object
        .Description
            Serves as a wrapper for ConvertTo-Metadata to explicitly support exporting to files

            Note that exportable data is limited by the rules of data sections (see about_Data_Sections) and the available MetadataSerializers (see Add-MetadataConverter)

            The only things inherently importable in PowerShell metadata files are Strings, Booleans, and Numbers ... and Arrays or Hashtables where the values (and keys) are all strings, booleans, or numbers.

            Note: this function and the matching Import-Metadata are extensible, and have included support for PSCustomObject, Guid, Version, etc.
        .Example
            $Configuration | Export-Metadata .\Configuration.psd1

            Export a configuration object (or hashtable) to the default Configuration.psd1 file for a module
            the metadata module uses Configuration.psd1 as it's default config file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Specifies the path to the PSD1 output file.
        [Parameter(Mandatory = $true, Position = 0)]
        $Path,

        # comments to place on the top of the file (to explain settings or whatever for people who might edit it by hand)
        [string[]]$CommentHeader,

        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        [Hashtable]$Converters = @{},

        # If set, output the nuspec file
        [Switch]$Passthru
    )
    begin {
        $data = @()
    }
    process {
        $data += @($InputObject)
    }
    end {
        # Avoid arrays when they're not needed:
        if ($data.Count -eq 1) {
            $data = $data[0]
        }
        Set-Content -Encoding UTF8 -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata -InputObject $data -Converters $Converters -AsHashtable:$AsHashtable)) -Join "`n")
        if ($Passthru) {
            Get-Item $Path
        }
    }
}
#EndRegion '.\Public\Export-Metadata.ps1' 60
#Region '.\Public\Get-Metadata.ps1' 0
function Get-Metadata {
    #.Synopsis
    #   Reads a specific value from a PowerShell metadata file (e.g. a module manifest)
    #.Description
    #   By default Get-Metadata gets the ModuleVersion, but it can read any key in the metadata file
    #.Example
    #   Get-Metadata .\Configuration.psd1
    #
    #   Returns the module version number (as a string)
    #.Example
    #   Get-Metadata .\Configuration.psd1 ReleaseNotes
    #
    #   Returns the release notes!
    [Alias("Get-ManifestValue")]
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        [ValidateScript( { if ([IO.Path]::GetExtension($_) -ne ".psd1") {
                    throw "Path must point to a .psd1 file"
                } $true })]
        [string]$Path,

        # The property (or dotted property path) to be read from the manifest.
        # Get-Metadata searches the Manifest root properties, and also the nested hashtable properties.
        [Parameter(ParameterSetName = "Overwrite", Position = 1)]
        [string]$PropertyName = 'ModuleVersion',

        [switch]$Passthru
    )
    process {
        $ErrorActionPreference = "Stop"

        if (!(Test-Path $Path)) {
            WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                -Message "Can't find file $Path" `
                -ErrorId "PathNotFound,Metadata\Import-Metadata" `
                -Category "ObjectNotFound"
            return
        }
        $Path = Convert-Path $Path

        $Tokens = $Null; $ParseErrors = $Null
        $AST = [System.Management.Automation.Language.Parser]::ParseFile( $Path, [ref]$Tokens, [ref]$ParseErrors )

        $KeyValue = $Ast.EndBlock.Statements
        $KeyValue = @(FindHashKeyValue $PropertyName $KeyValue)
        if ($KeyValue.Count -eq 0) {
            WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                -Message "Can't find '$PropertyName' in $Path" `
                -ErrorId "PropertyNotFound,Metadata\Get-Metadata" `
                -Category "ObjectNotFound"
            return
        }
        if ($KeyValue.Count -gt 1) {
            $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })

            if ($SingleKey.Count -ne 1) {
                WriteError -ExceptionType System.Reflection.AmbiguousMatchException `
                    -Message ("Found more than one '$PropertyName' in $Path. Please specify a dotted path instead. Matching paths include: '{0}'" -f ($KeyValue.HashKeyPath -join "', '")) `
                    -ErrorId "AmbiguousMatch,Metadata\Get-Metadata" `
                    -Category "InvalidArgument"
                return
            } else {
                $KeyValue = $SingleKey
            }
        }
        $KeyValue = $KeyValue[0]

        if ($Passthru) {
            $KeyValue
        } else {
            # # Write-Debug "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
            # # Write-Debug "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"

            # In PowerShell 5+ we can just use:
            if ($KeyValue.SafeGetValue) {
                $KeyValue.SafeGetValue()
            } else {
                # Otherwise, this worked for simple values:
                $Expression = $KeyValue.GetPureExpression()
                if ($Expression.Value) {
                    $Expression.Value
                } else {
                    # For complex (arrays, hashtables) we parse it ourselves
                    ConvertFrom-Metadata $KeyValue
                }
            }
        }
    }
}
#EndRegion '.\Public\Get-Metadata.ps1' 93
#Region '.\Public\Import-Metadata.ps1' 0
function Import-Metadata {
    <#
      .Synopsis
         Creates a data object from the items in a Metadata file (e.g. a .psd1)
      .Description
         Serves as a wrapper for ConvertFrom-Metadata to explicitly support importing from files
      .Example
         $data = Import-Metadata .\Configuration.psd1 -Ordered

         Convert a module manifest into a hashtable of properties for introspection, preserving the order in the file
   #>
    [CmdletBinding()]
    param(
        # The path to the metadata (.psd1) file to import
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath", "Content")]
        [string]$Path,

        # A hashtable of MetadataConverters (same as with Add-MetadataConverter)
        [Hashtable]$Converters = @{},

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in metadata
        # BEWARE: This exposes the value of these variables in the calling context to the metadata file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables,

        # You should not pass this.
        # The PSVariable parameter is for preserving variable scope within the Metadata commands
        [System.Management.Automation.PSVariableIntrinsics]$PSVariable
    )
    process {
        if (!$PSVariable) {
            $PSVariable = $PSCmdlet.SessionState.PSVariable
        }
        if (Test-Path $Path) {
            # Write-Debug "Importing Metadata file from `$Path: $Path"
            if (!(Test-Path $Path -PathType Leaf)) {
                $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
            }
        }
        if (!(Test-Path $Path)) {
            WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                -Message "Can't find file $Path" `
                -ErrorId "PathNotFound,Metadata\Import-Metadata" `
                -Category "ObjectNotFound"
            return
        }
        try {
            ConvertFrom-Metadata -InputObject $Path -Converters $Converters -Ordered:$Ordered -AllowedVariables $AllowedVariables -PSVariable $PSVariable
        } catch {
            ThrowError $_
        }
    }
}
#EndRegion '.\Public\Import-Metadata.ps1' 59
#Region '.\Public\Test-PSVersion.ps1' 0
function Test-PSVersion {
    <#
      .Synopsis
         Test the PowerShell Version
      .Description
         This function exists so I can do things differently on older versions of PowerShell.
         But the reason I test in a function is that I can mock the Version to test the alternative code.
      .Example
         if(Test-PSVersion -ge 3.0) {
            ls | where Length -gt 12mb
         } else {
            ls | Where { $_.Length -gt 12mb }
         }

         This is just a trivial example to show the usage (you wouldn't really bother for a where-object call)
   #>
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Version]$Version = $PSVersionTable.PSVersion,
        [Version]$lt,
        [Version]$le,
        [Version]$gt,
        [Version]$ge,
        [Version]$eq,
        [Version]$ne
    )

    $all = @(
        if ($lt) { $Version -lt $lt }
        if ($gt) { $Version -gt $gt }
        if ($le) { $Version -le $le }
        if ($ge) { $Version -ge $ge }
        if ($eq) { $Version -eq $eq }
        if ($ne) { $Version -ne $ne }
    )

    $all -notcontains $false
}
#EndRegion '.\Public\Test-PSVersion.ps1' 40
#Region '.\Public\Update-Metadata.ps1' 0
function Update-Metadata {
    <#
        .Synopsis
           Update a single value in a PowerShell metadata file
        .Description
           By default Update-Metadata increments "ModuleVersion"
           because my primary use of it is during builds,
           but you can pass the PropertyName and Value for any key in a module Manifest, its PrivateData, or the PSData in PrivateData.

           NOTE: This will not currently create new keys, or uncomment keys.
        .Example
           Update-Metadata .\Configuration.psd1

           Increments the Build part of the ModuleVersion in the Configuration.psd1 file
        .Example
           Update-Metadata .\Configuration.psd1 -Increment Major

           Increments the Major version part of the ModuleVersion in the Configuration.psd1 file
        .Example
           Update-Metadata .\Configuration.psd1 -Value '0.4'

           Sets the ModuleVersion in the Configuration.psd1 file to 0.4
        .Example
           Update-Metadata .\Configuration.psd1 -Property ReleaseNotes -Value 'Add the awesome Update-Metadata function!'

           Sets the PrivateData.PSData.ReleaseNotes value in the Configuration.psd1 file!
    #>
    [Alias("Update-Manifest")]
    # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the module manifest file -- must be a .psd1 file
        # As an easter egg, you can pass the CONTENT of a psd1 file instead, and the modified data will pass through
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        [ValidateScript( { if ([IO.Path]::GetExtension($_) -ne ".psd1") {
                    throw "Path must point to a .psd1 file"
                } $true })]
        [string]$Path,

        # The property to be set in the manifest. It must already exist in the file (and not be commented out)
        # This searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName = "Overwrite")]
        [string]$PropertyName = 'ModuleVersion',

        # A new value for the property
        [Parameter(ParameterSetName = "Overwrite", Mandatory)]
        $Value,

        # By default Update-Metadata increments ModuleVersion; this controls which part of the version number is incremented
        [Parameter(ParameterSetName = "IncrementVersion")]
        [ValidateSet("Major", "Minor", "Build", "Revision")]
        [string]$Increment = "Build",

        # When set, and incrementing the ModuleVersion, output the new version number.
        [Parameter(ParameterSetName = "IncrementVersion")]
        [switch]$Passthru
    )
    process {
        $KeyValue = Get-Metadata $Path -PropertyName $PropertyName -Passthru

        if ($PSCmdlet.ParameterSetName -eq "IncrementVersion") {
            $Version = [Version]$KeyValue.GetPureExpression().Value # SafeGetValue()

            $Version = switch ($Increment) {
                "Major" {
                    [Version]::new($Version.Major + 1, 0)
                }
                "Minor" {
                    $Minor = if ($Version.Minor -le 0) {
                        1
                    } else {
                        $Version.Minor + 1
                    }
                    [Version]::new($Version.Major, $Minor)
                }
                "Build" {
                    $Build = if ($Version.Build -le 0) {
                        1
                    } else {
                        $Version.Build + 1
                    }
                    [Version]::new($Version.Major, $Version.Minor, $Build)
                }
                "Revision" {
                    $Build = if ($Version.Build -le 0) {
                        0
                    } else {
                        $Version.Build
                    }
                    $Revision = if ($Version.Revision -le 0) {
                        1
                    } else {
                        $Version.Revision + 1
                    }
                    [Version]::new($Version.Major, $Version.Minor, $Build, $Revision)
                }
            }

            $Value = $Version

            if ($Passthru) {
                $Value
            }
        }

        $Value = ConvertTo-Metadata $Value

        $Extent = $KeyValue.Extent
        while ($KeyValue.parent) {
            $KeyValue = $KeyValue.parent
        }

        $ManifestContent = $KeyValue.Extent.Text.Remove(
            $Extent.StartOffset,
            ($Extent.EndOffset - $Extent.StartOffset)
        ).Insert($Extent.StartOffset, $Value).Trim()

        if (Test-Path $Path) {
            Set-Content -Encoding UTF8 -Path $Path -Value $ManifestContent
        } else {
            $ManifestContent
        }
    }
}
#EndRegion '.\Public\Update-Metadata.ps1' 127
#Region '.\Public\Update-Object.ps1' 0
function Update-Object {
    <#
      .Synopsis
         Recursively updates a hashtable or custom object with new values
      .Description
         Updates the InputObject with data from the update object, updating or adding values.
      .Example
         Update-Object -Input @{
            One = "Un"
            Two = "Dos"
         } -Update @{
            One = "Uno"
            Three = "Tres"
         }

         Updates the InputObject with the values in the UpdateObject,
         will return the following object:

         @{
            One = "Uno"
            Two = "Dos"
            Three = "Tres"
         }
   #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The object (or hashtable) with properties (or keys) to overwrite the InputObject
        [AllowNull()]
        [Parameter(Position = 0, Mandatory = $true)]
        $UpdateObject,

        # This base object (or hashtable) will be updated and overwritten by the UpdateObject
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        $InputObject,

        # A list of values which (if found on InputObject) should not be updated from UpdateObject
        [Parameter()]
        [string[]]$ImportantInputProperties
    )
    process {
        # Write-Debug "INPUT OBJECT:"
        # Write-Debug (($InputObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
        # Write-Debug "Update OBJECT:"
        # Write-Debug (($UpdateObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
        if ($Null -eq $InputObject) {
            return
        }

        # $InputObject -is [PSCustomObject] -or
        if ($InputObject -is [System.Collections.IDictionary]) {
            $OutputObject = $InputObject
        } else {
            # Create a PSCustomObject with all the properties
            $OutputObject = [PSObject]$InputObject # | Select-Object * | % { }
        }

        if (!$UpdateObject) {
            $OutputObject
            return
        }

        if ($UpdateObject -is [System.Collections.IDictionary]) {
            $Keys = $UpdateObject.Keys
        } else {
            $Keys = @($UpdateObject |
                    Get-Member -MemberType Properties |
                    Where-Object { $p1 -notcontains $_.Name } |
                    Select-Object -ExpandProperty Name)
        }

        function TestKey {
            [OutputType([bool])]
            [CmdletBinding()]
            param($InputObject, $Key)
            [bool]$(
                if ($InputObject -is [System.Collections.IDictionary]) {
                    $InputObject.ContainsKey($Key)
                } else {
                    Get-Member -InputObject $InputObject -Name $Key
                }
            )
        }

        # # Write-Debug "Keys: $Keys"
        foreach ($key in $Keys) {
            if ($key -notin $ImportantInputProperties -or -not (TestKey -InputObject $InputObject -Key $Key) ) {
                # recurse Dictionaries (hashtables) and PSObjects
                if (($OutputObject.$Key -is [System.Collections.IDictionary] -or $OutputObject.$Key -is [PSObject]) -and
                    ($InputObject.$Key -is [System.Collections.IDictionary] -or $InputObject.$Key -is [PSObject])) {
                    $Value = Update-Object -InputObject $InputObject.$Key -UpdateObject $UpdateObject.$Key
                } else {
                    $Value = $UpdateObject.$Key
                }

                if ($OutputObject -is [System.Collections.IDictionary]) {
                    $OutputObject.$key = $Value
                } else {
                    $OutputObject = Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name $key -Value $Value -PassThru -Force
                }
            }
        }

        $OutputObject
    }
}
#EndRegion '.\Public\Update-Object.ps1' 107
#Region '.\Footer\InitialMetadataConverters.ps1' 0
$MetadataSerializers = @{}
$MetadataDeserializers = @{}

if ($Converters -is [Collections.IDictionary]) {
    Add-MetadataConverter $Converters
}
function PSCredentialMetadataConverter {
    <#
    .Synopsis
        Creates a new PSCredential with the specified properties
    .Description
        This is just a wrapper for the PSObject constructor with -Property $Value
        It exists purely for the sake of psd1 serialization
    .Parameter Value
        The hashtable of properties to add to the created objects
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "EncodedPassword")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPasswordParams", "")]
    param(
        # The UserName for this credential
        [string]$UserName,
        # The Password for this credential, encoded via ConvertFrom-SecureString
        [string]$EncodedPassword
    )
    New-Object PSCredential $UserName, (ConvertTo-SecureString $EncodedPassword)
}

# The OriginalMetadataSerializers
Add-MetadataConverter @{
    [bool]           = { if ($_) { '$True' } else { '$False' } }
    [Version]        = { "'$_'" }
    [PSCredential]   = { 'PSCredential "{0}" "{1}"' -f $_.UserName, (ConvertFrom-SecureString $_.Password) }
    [SecureString]   = { "ConvertTo-SecureString {0}" -f (ConvertFrom-SecureString $_) }
    [Guid]           = { "Guid '$_'" }
    [DateTime]       = { "DateTime '{0}'" -f $InputObject.ToString('o') }
    [DateTimeOffset] = { "DateTimeOffset '{0}'" -f $InputObject.ToString('o') }
    [ConsoleColor]   = { "ConsoleColor {0}" -f $InputObject.ToString() }

    [System.Management.Automation.SwitchParameter] = { if ($_) { '$True' } else { '$False' } }
    # This GUID is here instead of as a function
    # just to make sure the tests can validate the converter hashtables
    "Guid"           = { [Guid]$Args[0] }
    "DateTime"       = { [DateTime]$Args[0] }
    "DateTimeOffset" = { [DateTimeOffset]$Args[0] }
    "ConsoleColor"   = { [ConsoleColor]$Args[0] }
    "ScriptBlock"    = { [scriptblock]::Create($Args[0]) }
    "PSCredential"   = (Get-Command PSCredentialMetadataConverter).ScriptBlock
    "FromPsMetadata" = {
        $TypeName, $Args = $Args
        $Output = ([Type]$TypeName)::new()
        $Output.FromPsMetadata($Args)
        $Output
    }
    "PSObject"       = { param([hashtable]$Properties, [string[]]$TypeName)
        $Result = New-Object System.Management.Automation.PSObject -Property $Properties
        $TypeName += @($Result.PSTypeNames)
        $Result.PSTypeNames.Clear()
        foreach ($Name in $TypeName) {
            $Result.PSTypeNames.Add($Name)
        }
        $Result }

}

$Script:OriginalMetadataSerializers = $script:MetadataSerializers.Clone()
$Script:OriginalMetadataDeserializers = $script:MetadataDeserializers.Clone()

Export-ModuleMember -Function *-* -Alias *
#EndRegion '.\Footer\InitialMetadataConverters.ps1' 69
