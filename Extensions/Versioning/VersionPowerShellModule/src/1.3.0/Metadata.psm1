param(
   $Converters = @{}
)

$ModuleManifestExtension = ".psd1"

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
      if($lt) { $Version -lt $lt }
      if($gt) { $Version -gt $gt }
      if($le) { $Version -le $le }
      if($ge) { $Version -ge $ge }
      if($eq) { $Version -eq $eq }
      if($ne) { $Version -ne $ne }
   )

   $all -notcontains $false
}

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

   if($Converters.Count) {
      switch ($Converters.Keys.GetEnumerator()) {
         {$Converters[$_] -isnot [ScriptBlock]} {
            WriteError -ExceptionType System.ArgumentExceptionn `
                    -Message "Ignoring $_ converter, the value must be ScriptBlock!" `
                    -ErrorId "NotAScriptBlock,Metadata\Add-MetadataConverter" `
                    -Category "InvalidArgument"
            continue
         }

         {$_ -is [String]}
         {
            # Write-Debug "Storing deserialization function: $_"
            Set-Content "function:script:$_" $Converters[$_]
            # We need to store the function in MetadataDeserializers
            $MetadataDeserializers[$_] = $Converters[$_]
            continue
         }

         {$_ -is [Type]}
         {
            # Write-Debug "Adding serializer for $($_.FullName)"
            $MetadataSerializers[$_] = $Converters[$_]
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
      if($Null -eq $InputObject) {
        '""'
      } elseif( $InputObject -is [Int16] -or
                $InputObject -is [Int32] -or
                $InputObject -is [Int64] -or
                $InputObject -is [Double] -or
                $InputObject -is [Decimal] -or
                $InputObject -is [Byte] )
      {
         "$InputObject"
      }
      elseif($InputObject -is [String]) {
         "'{0}'" -f $InputObject.ToString().Replace("'","''")
      }
      elseif($InputObject -is [Collections.IDictionary]) {
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in @($InputObject.Keys)) {
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key) -AsHashtable:$AsHashtable)
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key) -AsHashtable:$AsHashtable)
            }
         }) -split "`n" -join "`n$t")
      }
      elseif($InputObject -is [System.Collections.IEnumerable]) {
         "@($($(ForEach($item in @($InputObject)) { ConvertTo-Metadata $item -AsHashtable:$AsHashtable}) -join ","))"
      }
      elseif($InputObject -is [System.Management.Automation.ScriptBlock]) {
         "(ScriptBlock '$InputObject')"
      }
      elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
         $(if($AsHashtable) {
             "@{{`n$t{0}`n}}"
         } else {
            "(PSObject @{{`n$t{0}`n}})"
         }) -f ($(
            ForEach($key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name) {
               if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
                  "$key = " + (ConvertTo-Metadata $InputObject.$key -AsHashtable:$AsHashtable)
               }
               else {
                  "'$key' = " + (ConvertTo-Metadata $InputObject.$key -AsHashtable:$AsHashtable)
               }
            }
         ) -split "`n" -join "`n$t")
      }
      elseif($MetadataSerializers.ContainsKey($InputObject.GetType())) {
         $Str = ForEach-Object $MetadataSerializers.($InputObject.GetType()) -InputObject $InputObject

         [bool]$IsCommand = & {
            $ErrorActionPreference = "Stop"
            $Tokens = $Null; $ParseErrors = $Null
            $AST = [System.Management.Automation.Language.Parser]::ParseInput( $Str, [ref]$Tokens, [ref]$ParseErrors)
            $Null -ne $Ast.Find({$args[0] -is [System.Management.Automation.Language.CommandAst]}, $false)
         }

         if($IsCommand) { "($Str)" } else { $Str }
      }
      else {
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString().Replace("'","`'`'")
      }
   }
}

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
      [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
      [Alias("PSPath")]
      $InputObject,

      [Hashtable]$Converters = @{},

      $ScriptRoot = "$PSScriptRoot",

      # If set (and PowerShell version 4 or later) preserve the file order of configuration
      # This results in the output being an OrderedDictionary instead of Hashtable
      [Switch]$Ordered
   )
   begin {
      $Script:OriginalMetadataSerializers = $Script:MetadataSerializers.Clone()
      $Script:OriginalMetadataDeserializers = $Script:MetadataDeserializers.Clone()
      Add-MetadataConverter $Converters
      [string[]]$ValidCommands = @(
            "ConvertFrom-StringData", "Join-Path", "Split-Path", "ConvertTo-SecureString"
         ) + @($MetadataDeserializers.Keys)
      [string[]]$ValidVariables = "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot","PSCulture","PSUICulture","True","False","Null"
   }
   end {
      $Script:MetadataSerializers = $Script:OriginalMetadataSerializers.Clone()
      $Script:MetadataDeserializers = $Script:OriginalMetadataDeserializers.Clone()
   }
   process {
      $ErrorActionPreference = "Stop"
      $Tokens = $Null; $ParseErrors = $Null

      if(Test-PSVersion -lt "3.0") {
         # Write-Debug "$InputObject"
         if(!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Set-Content -Encoding UTF8 -Path $Path $InputObject
            $InputObject = $Path
         } elseif(!"$InputObject".EndsWith($ModuleManifestExtension)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Copy-Item "$InputObject" "$Path"
            $InputObject = $Path
         }
         $Result = $null
         Import-LocalizedData -BindingVariable Result -BaseDirectory (Split-Path $InputObject) -FileName (Split-Path $InputObject -Leaf) -SupportedCommand $ValidCommands
         return $Result
      }

      if(Test-Path $InputObject -ErrorAction SilentlyContinue) {
         # ParseFile on PS5 (and older) doesn't handle utf8 encoding properly (treats it as ASCII)
         # Sometimes, that causes an avoidable error. So I'm avoiding it, if I can:
         $Ex = $_
         $Path = Convert-Path $InputObject
         if(!$PSBoundParameters.ContainsKey('ScriptRoot')) {
            $ScriptRoot = Split-Path $Path
         }
         $Content = (Get-Content -Path $InputObject -Encoding UTF8)
         # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
         $Content = $Content -join "`n" -replace "# SIG # Begin signature block(?s:.*)"
         try {
            # But older versions of PowerShell, this will throw a MethodException because the overload is missing
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, $Path, [ref]$Tokens, [ref]$ParseErrors)
         } catch [System.Management.Automation.MethodException] {
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
         if (!$PSBoundParameters.ContainsKey('ScriptRoot')) {
            $ScriptRoot = $PoshCodeModuleRoot
         }

         $OFS = "`n"
         # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
         $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
      }

      if($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
         ThrowError -Exception (New-Object System.Management.Automation.ParseException (,[System.Management.Automation.Language.ParseError[]]$ParseErrors)) -ErrorId "Metadata Error" -Category "ParserError" -TargetObject $InputObject
      }

      # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
      $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -ExpandProperty NestedTokens

      # Work around PowerShell rules about magic variables
      # Replace "PSScriptRoot" magic variables with the non-reserved "ScriptRoot"
      if($scriptroots = @($Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -eq "PSScriptRoot") } | ForEach-Object { $_.Extent } )) {
         $ScriptContent = $Ast.ToString()
         for($r = $scriptroots.count - 1; $r -ge 0; $r--) {
            $ScriptContent = $ScriptContent.Remove($scriptroots[$r].StartOffset, ($scriptroots[$r].EndOffset - $scriptroots[$r].StartOffset)).Insert($scriptroots[$r].StartOffset,'$ScriptRoot')
         }
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
      }

      $Script = $AST.GetScriptBlock()
      try {
         $Script.CheckRestrictedLanguage( $ValidCommands, $ValidVariables, $true )
      }
      catch {
         ThrowError -Exception $_.Exception.InnerException -ErrorId "Metadata Error" -Category "InvalidData" -TargetObject $Script
      }

      if($Ordered -and (Test-PSVersion -gt "3.0")) {
         # Make all the hashtables ordered, so that the output objects make more sense to humans...
         if($Tokens | Where-Object { "AtCurly" -eq $_.Kind }) {
            $ScriptContent = $AST.ToString()
            $Hashtables = $AST.FindAll({$args[0] -is [System.Management.Automation.Language.HashtableAst] -and ("ordered" -ne $args[0].Parent.Type.TypeName)}, $Recurse)
            $Hashtables = $Hashtables | ForEach-Object {
                                            New-Object PSObject -Property @{Type="([ordered]";Position=$_.Extent.StartOffset}
                                            New-Object PSObject -Property @{Type=")";Position=$_.Extent.EndOffset}
                                          } | Sort-Object Position -Descending
            foreach($point in $Hashtables) {
               $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
            }
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
            $Script = $AST.GetScriptBlock()
         }
      }

      $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

      try {
         $Script.InvokeReturnAsIs(@())
      }
      finally {
         $ExecutionContext.SessionState.LanguageMode = $Mode
      }
   }
}

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
      [Parameter(ValueFromPipeline=$true, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath","Content")]
      [string]$Path,

      [Hashtable]$Converters = @{},

       # If set (and PowerShell version 4 or later) preserve the file order of configuration
       # This results in the output being an OrderedDictionary instead of Hashtable
      [Switch]$Ordered
   )
   process {
      if(Test-Path $Path) {
         # Write-Debug "Importing Metadata file from `$Path: $Path"
         if(!(Test-Path $Path -PathType Leaf)) {
            $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
         }
      }
      if(!(Test-Path $Path)) {
         WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                    -Message "Can't find file $Path" `
                    -ErrorId "PathNotFound,Metadata\Import-Metadata" `
                    -Category "ObjectNotFound"
         return
      }
      try {
         ConvertFrom-Metadata -InputObject $Path -Converters $Converters -Ordered:$Ordered
      } catch {
         ThrowError $_
      }
   }
}

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
            The Configuration module uses Configuration.psd1 as it's default config file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Specifies the path to the PSD1 output file.
        [Parameter(Mandatory=$true, Position=0)]
        $Path,

        # comments to place on the top of the file (to explain settings or whatever for people who might edit it by hand)
        [string[]]$CommentHeader,

        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        [Hashtable]$Converters = @{},

        # If set, output the nuspec file
        [Switch]$Passthru
    )
    begin { $data = @() }
    process { $data += @($InputObject) }
    end {
        # Avoid arrays when they're not needed:
        if($data.Count -eq 1) { $data = $data[0] }
        Set-Content -Encoding UTF8 -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata -InputObject $data -Converters $Converters -AsHashtable:$AsHashtable)) -Join "`n")
        if($Passthru) {
            Get-Item $Path
        }
    }
}

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the module manifest file -- must be a .psd1 file
        # As an easter egg, you can pass the CONTENT of a psd1 file instead, and the modified data will pass through
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [ValidateScript({ if([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" } $true })]
        [string]$Path,

        # The property to be set in the manifest. It must already exist in the file (and not be commented out)
        # This searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName="Overwrite")]
        [string]$PropertyName = 'ModuleVersion',

        # A new value for the property
        [Parameter(ParameterSetName="Overwrite", Mandatory)]
        $Value,

        # By default Update-Metadata increments ModuleVersion; this controls which part of the version number is incremented
        [Parameter(ParameterSetName="IncrementVersion")]
        [ValidateSet("Major","Minor","Build","Revision")]
        [string]$Increment = "Build",

        # When set, and incrementing the ModuleVersion, output the new version number.
        [Parameter(ParameterSetName="IncrementVersion")]
        [switch]$Passthru
    )

    $KeyValue = Get-Metadata $Path -PropertyName $PropertyName -Passthru

    if($PSCmdlet.ParameterSetName -eq "IncrementVersion") {
        $Version = [Version]$KeyValue.SafeGetValue()

        $Version = switch($Increment) {
            "Major" {
                [Version]::new($Version.Major + 1, 0)
            }
            "Minor" {
                $Minor = if($Version.Minor -le 0) { 1 } else { $Version.Minor + 1 }
                [Version]::new($Version.Major, $Minor)
            }
            "Build" {
                $Build = if($Version.Build -le 0) { 1 } else { $Version.Build + 1 }
                [Version]::new($Version.Major, $Version.Minor, $Build)
            }
            "Revision" {
                $Build = if($Version.Build -le 0) { 0 } else { $Version.Build }
                $Revision = if($Version.Revision -le 0) { 1 } else { $Version.Revision + 1 }
                [Version]::new($Version.Major, $Version.Minor, $Build, $Revision)
            }
        }

        $Value = $Version

        if($Passthru) { $Value }
    }

    $Value = ConvertTo-Metadata $Value

    $Extent = $KeyValue.Extent
    while($KeyValue.parent) { $KeyValue = $KeyValue.parent }

    $ManifestContent = $KeyValue.Extent.Text.Remove(
                                               $Extent.StartOffset,
                                               ($Extent.EndOffset - $Extent.StartOffset)
                                           ).Insert($Extent.StartOffset, $Value)

    if(Test-Path $Path) {
        Set-Content -Encoding UTF8 -Path $Path -Value $ManifestContent
    } else {
        $ManifestContent
    }
}

function FindHashKeyValue {
    [CmdletBinding()]
    param(
        $SearchPath,
        $Ast,
        [string[]]
        $CurrentPath = @()
    )
    # Write-Debug "FindHashKeyValue: $SearchPath -eq $($CurrentPath -Join '.')"
    if($SearchPath -eq ($CurrentPath -Join '.') -or $SearchPath -eq $CurrentPath[-1]) {
        return $Ast |
            Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force |
            Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }

    if($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst] ) {
        $KeyValue = $Ast.PipelineElements.Expression
        foreach($KV in $KeyValue.KeyValuePairs) {
            $result = FindHashKeyValue $SearchPath -Ast $KV.Item2 -CurrentPath ($CurrentPath + $KV.Item1.Value)
            if($null -ne $result) {
                $result
            }
        }
    }
}

function Get-Metadata {
    #.Synopsis
    #   Reads a specific value from a PowerShell metdata file (e.g. a module manifest)
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
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [ValidateScript({ if([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" } $true })]
        [string]$Path,

        # The property (or dotted property path) to be read from the manifest.
        # Get-Metadata searches the Manifest root properties, and also the nested hashtable properties.
        [Parameter(ParameterSetName="Overwrite", Position=1)]
        [string]$PropertyName = 'ModuleVersion',

        [switch]$Passthru
    )
    $ErrorActionPreference = "Stop"

    if(!(Test-Path $Path)) {
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
    if($KeyValue.Count -eq 0) {
        WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                   -Message "Can't find '$PropertyName' in $Path" `
                   -ErrorId "PropertyNotFound,Metadata\Get-Metadata" `
                   -Category "ObjectNotFound"
        return
    }
    if($KeyValue.Count -gt 1) {
        $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })

        if($SingleKey.Count -gt 1) {
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

    if($Passthru) { $KeyValue } else {
        # # Write-Debug "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
        # # Write-Debug "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"
        $KeyValue.SafeGetValue()
    }
}

Set-Alias Update-Manifest Update-Metadata
Set-Alias Get-ManifestValue Get-Metadata

$MetadataSerializers = @{}
$MetadataDeserializers = @{}

if($Converters -is [Collections.IDictionary]) {
   Add-MetadataConverter $Converters
}

# The OriginalMetadataSerializers
Add-MetadataConverter @{
   [bool]           = { if($_) { '$True' } else { '$False' } }
   [Version]        = { "'$_'" }
   [PSCredential]   = { 'PSCredential "{0}" "{1}"' -f $_.UserName, (ConvertFrom-SecureString $_.Password) }
   [SecureString]   = { "ConvertTo-SecureString {0}" -f (ConvertFrom-SecureString $_) }
   [Guid]           = { "Guid '$_'" }
   [DateTime]       = { "DateTime '{0}'" -f $InputObject.ToString('o') }
   [DateTimeOffset] = { "DateTimeOffset '{0}'" -f $InputObject.ToString('o') }
   [ConsoleColor]   = { "ConsoleColor {0}" -f $InputObject.ToString() }

   [System.Management.Automation.SwitchParameter] = { if($_) { '$True' } else { '$False' } }

    # This GUID is here instead of as a function
    # just to make sure the tests can validate the converter hashtables
    "Guid"           = { [Guid]$Args[0] }
    "PSObject"       = { New-Object System.Management.Automation.PSObject -Property $Args[0] }
    "DateTime"       = { [DateTime]$Args[0] }
    "DateTimeOffset" = { [DateTimeOffset]$Args[0] }
    "ConsoleColor"   = { [ConsoleColor]$Args[0] }
    "ScriptBlock"    = { [scriptblock]::Create($Args[0]) }
    "PSCredential"   = {
        <#
        .Synopsis
            Creates a new PSCredential with the specified properties
        .Description
            This is just a wrapper for the PSObject constructor with -Property $Value
            It exists purely for the sake of psd1 serialization
        .Parameter Value
            The hashtable of properties to add to the created objects
        #>
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword","EncodedPassword")]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPasswordParams","")]
        param(
            # The UserName for this credential
            [string]$UserName,
            # The Password for this credential, encoded via ConvertFrom-SecureString
            [string]$EncodedPassword
        )
        New-Object PSCredential $UserName, (ConvertTo-SecureString $EncodedPassword)
    }

}

$Script:OriginalMetadataSerializers = $MetadataSerializers.Clone()
$Script:OriginalMetadataDeserializers = $MetadataDeserializers.Clone()

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
   param(
      # The object (or hashtable) with properties (or keys) to overwrite the InputObject
      [AllowNull()]
      [Parameter(Position=0, Mandatory=$true)]
      $UpdateObject,

      # This base object (or hashtable) will be updated and overwritten by the UpdateObject
      [Parameter(ValueFromPipeline=$true, Mandatory = $true)]
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
      if($Null -eq $InputObject) { return }

      # $InputObject -is [PSCustomObject] -or
      if ($InputObject -is [System.Collections.IDictionary]) {
         $OutputObject = $InputObject
      } else {
         # Create a PSCustomObject with all the properties
         $OutputObject = [PSObject]$InputObject # | Select-Object * | % { }
      }

      if(!$UpdateObject) {
         $OutputObject
         return
      }

      if($UpdateObject -is [System.Collections.IDictionary]) {
         $Keys = $UpdateObject.Keys
      } else {
         $Keys = @($UpdateObject |
                    Get-Member -MemberType Properties |
                    Where-Object { $p1 -notcontains $_.Name } |
                    Select-Object -ExpandProperty Name)
      }

      function TestKey {
         [CmdletBinding()]
         param($InputObject, $Key)
         [bool]$(
            if($InputObject -is [System.Collections.IDictionary]) {
               $InputObject.ContainsKey($Key)
            } else {
               Get-Member -InputObject $InputObject -Name $Key
            }
         )
      }

      # # Write-Debug "Keys: $Keys"
      foreach($key in $Keys) {
         if($key -notin $ImportantInputProperties -or -not (TestKey -InputObject $InputObject -Key $Key) ) {
            # recurse Dictionaries (hashtables) and PSObjects
            if(($OutputObject.$Key -is [System.Collections.IDictionary] -or $OutputObject.$Key -is [PSObject]) -and
                ($InputObject.$Key -is  [System.Collections.IDictionary] -or $InputObject.$Key -is [PSObject])) {
                $Value = Update-Object -InputObject $InputObject.$Key -UpdateObject $UpdateObject.$Key
            } else {
                $Value = $UpdateObject.$Key
            }

            if($OutputObject -is [System.Collections.IDictionary]) {
                $OutputObject.$key = $Value
            } else {
                $OutputObject = Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name $key -Value $Value -PassThru -Force
            }
         }
      }

      $OutputObject
   }
}

# Utility to throw an errorrecord
function ThrowError {
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName="NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName="NewException", Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType="System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=10)]
        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=11)]
        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName="Rethrow", Position=1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if(!$ErrorRecord) {
            if($PSCmdlet.ParameterSetName -eq "NewException") {
                if($Exception) {
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

# Utility to throw an errorrecord
function WriteError {
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName="NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName="NewException", Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType="System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, Position=10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, Position=11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName="Rethrow", Position=1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if(!$ErrorRecord) {
            if($PSCmdlet.ParameterSetName -eq "NewException") {
                if($Exception) {
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

Export-ModuleMember -Function *-* -Alias *

# SIG # Begin signature block
# MIIXzgYJKoZIhvcNAQcCoIIXvzCCF7sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUU6tn/zNDzs4BwIuxdWc9acO+
# xc6gghMBMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggUwMIIEGKADAgEC
# AhAFmB+6PJIk/oqP7b4FPfHsMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMTcwNjE0MDAwMDAwWhcNMTgwNjAxMTIwMDAwWjBtMQswCQYDVQQG
# EwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3QgSGVucmlldHRh
# MRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pvZWwgSC4gQmVu
# bmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANALmLHevB7LvTmI
# p2oVErnz915fP1JUKoC+/5BRWUtAGooxg95jxX8+qT1yc02ZnkK7u1UyM0Mfs3b8
# MzhSqe5OkkQeT2RHrGe52+0/0ZWD68pvUBZoMQxrAnWJETjFO6IoXPKmoXN3zzpF
# +5s/UIbNGI5mdiN4v4F93Yaajzu2ymsJsXK6NgRh/AUbUzUlefpOas+o06wT0vqp
# LniGWw26321zJo//2QEo5PBrJvDDDIBBN6Xn5A2ww6v6fH2KGk2qf4vpr58rhDIH
# fLOHLg9s35effaktygUMQBCFmxOAbPLKWId8n5+O7zbMfKw3qxqCp2QeXhjkIh9v
# ETIX9pECAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZl
# dQ5YMB0GA1UdDgQWBBQ8xh3xoTXbMfJUSyFBfPsrxoD8XzAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGG
# L2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MEwGA1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcw
# AoZCaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3Vy
# ZWRJRENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
# BQADggEBAGvlfIiin9JAyL16oeCNApnAWLfZpUBob4D+XLzdRJXidPq/pvNkE9Rg
# pRZFaWs30f2WPhWeqCpSCahoHzFsD5S9mOzsGTXsT+EdjAS0yEe1t9LfMvEC/pI3
# aBQJeJ/DdgpTMUEUJSvddc0P0NbDJ6TJC/niEMOJ8XvsfF75J4YVJ10yVNahbAuU
# MrRrRLe30pW74MRv1s7SKxwPmLhcsMQuK0mWGERtGYMwDHwW0ZdRHKNDGHRsl0Wh
# DS1P8+JRpE3eNFPcO17yiOfKDnVh+/1AOg7QopD6R6+P9rErorebsvW680s4WTlr
# hDcMsTOX0js2KFF6uT4nSojS4GNlSxExggQ3MIIEMwIBATCBhjByMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBT
# aWduaW5nIENBAhAFmB+6PJIk/oqP7b4FPfHsMAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRtoA+w
# nCcHjQn7Ij7Hlj25d5xIXDANBgkqhkiG9w0BAQEFAASCAQDN+zbX8fDtKO91wDuM
# Q6NI5KvA8A4LuyKJXpNp7LytX3EMtgB/FtCbs91JRp92GhU7WVsyaPhJiUCEWExD
# uo5FV4kVvjnMTSY5EmZ/nxR5Zv88bUXWQkyVf/iEIRPyFF180lIIb1TG8vDw7p0c
# KCx/Kj1UcTmrozdIcm2oinubdD5C5U9yRmNjRwl4PxQYBThGvADfY4U4Yxu1XPM7
# QfFL2Il/s0PfSulD5R8uVJlqLus7mGwUoMhmlnuShmzuvGge6hGH5O5yfJnNdUeK
# ZMUV2yGfefIB+yviVCyQofN0T1UdE5SL3l4wjZ98yHpQliNxLzluLu2rDeLgZ3fg
# Q/bqoYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE4MDUwMTE0MzM0NVowIwYJKoZIhvcNAQkEMRYEFGgnTJaV
# GBdyBclzS/pJ8mcgmMoVMA0GCSqGSIb3DQEBAQUABIIBACvWETQqrXGbFapkdYqk
# fO6sQu3W5zu+zMWrXN+zEbYpGP+IAX4jUKpFPD+9HcCfhLo9M7YHSrbh2TkHQaqo
# ts1fbBxUXUjVtIRlnZ+S49PMMJuFmEAAlRgKNqzef0kNGxNtMtgRp0ewpkfOq1i5
# H3SZUkiAGRCGfID+l6PUm6tk4sMznZlt+cp0O4VZ6knWipTJ1eBuA5jD1hL//URN
# pYjhIhEKZRilijY824PybJVqwNrd+TVFrGkTlAj276BTMPg4Hhz1SGCSlKdF78hc
# ljTPHkbbSAvS+0qfhFQlbDy2MdcoKsuoAilDV/GD8eleQCL/j6KAQGRxzOLtcAQd
# a1w=
# SIG # End signature block
