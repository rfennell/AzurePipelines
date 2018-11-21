##-----------------------------------------------------------------------
## <copyright file="Generate-YAMLDocumation.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# A tools to scan a folder structure for task.json files and generate some 
# markdown for documentation use
#
# The output is a .MD file each Azure DevOps extensions, containing one or 
# more task details
#
# The output folder is deleted prior to use


param
(
    [Parameter(
        Mandatory=$true,
        HelpMessage="Please enter the base path to scan recursivally")]
    $path,
    [Parameter(
        Mandatory=$true,
        HelpMessage="Please enter the folder name to drop the .MD files into")]
    $outdir 
)

function GetExtenstion($path)
{
    $path = $jsonfile.DirectoryName.Split("\")
    if (($path[-2] -eq 'Pester') -or ($path[-2] -eq 'StyleCop'))
    {
        return $path[-2]
    }
    elseif (($path[-1] -eq "src") -or ($path[-1] -eq "task"))
    {
        return $path[-3]
    } else {
        return $path[-2]
    }
}

function GetTask($path)
{
    $path = $jsonfile.DirectoryName.Split("\")
    if (($path[-1] -eq "src") -or ($path[-1] -eq "task"))
    { 
        return $path[-2]
    } else {
        return $path[-1]
    }
}

function DumpField($field) 
{
    $line = New-Object System.Collections.Generic.List[System.Object]
    $line.Add("- **Argument:** " + $field.name)
    $line.Add("    - **Description:** " + $field.helpMarkDown)
    $line.Add("    - **Type:** " + $field.type )
    if ($field.type -eq "picklist")
    {
       foreach ($option in $field.options.psobject.Members |? {$_.Membertype -eq "noteproperty"} |  %{ $_.Name }) 
       {
            $line.Add("        - " + $option )
       }
    }
    $line.Add("    - **Required:** " + $field.required )
    $line.Add("    - **Default (if defined):** " + $field.defaultValue )
    return $line
}

if (-not (Test-Path $outdir))
{
    Write-Host "Creating folder '$outdir'"
    New-Item -ItemType directory -Path $outdir > $null
} else {
    Write-Host "Cleaning folder '$outdir'"
    Remove-Item $outdir\* -Recurse -Force
}

Write-Host "Scanning for task.json files under '$path'"
# Note we look for tasks so we see extensions multiple times
foreach ($jsonfile in Get-ChildItem -Path $path -Filter "task.json" -Recurse)
{
    $extension = GetExtenstion($jsonfile.DirectoryName)
    write-host "   Extension: $extension"
    $task = GetTask($jsonfile.DirectoryName)
    write-host "   Task: $task"
    $filepath = "$outdir\$extension.md"
 
    # Make sure only create a file ones
    if (-not (Test-Path $filepath))
    {
       Write-Host "       Creating .MD file"
       "# $extension " | Out-File -FilePath $filepath -Append 
       "The $extension package contains the following tasks. The table show the possible variables that can be used in YAML Azure DevOps Pipeline configurations " | Out-File -FilePath $filepath -Append 
    }    

    Write-Host "       Adding YAML sample"
    # have tried simple PS dump and a markdown table, neither looks good, so some manual formatting
    $json = Get-Content $jsonfile.FullName | ConvertFrom-Json
    "## $task " | Out-File -FilePath $filepath -Append 
    $json.description | Out-File -FilePath $filepath -Append 
    "### YAML snippet " | Out-File -FilePath $filepath -Append 
    "``````" | Out-File -FilePath $filepath -Append 
    "# " + $json.friendlyName  | Out-File -FilePath $filepath -Append 
    "# Description - " + $json.description | Out-File -FilePath $filepath -Append 
    "- task: " + $json.name | Out-File -FilePath $filepath -Append 
    "  inputs: " | Out-File -FilePath $filepath -Append 
    "     # Required arguments" | Out-File -FilePath $filepath -Append 
    foreach ($field in $json.inputs)
    {
        if ($field.required -eq "True")
        {
            "     " + $field.name + ": " + $field.defaultValue | Out-File -FilePath $filepath -Append 
        }
    }
    "``````" | Out-File -FilePath $filepath -Append 

    Write-Host "       Adding standard arguments"
    "### Arguments " | Out-File -FilePath $filepath -Append 

    # build the list of groups
    $groups = New-Object System.Collections.Generic.List[System.Object]
    foreach ($group in $json.groups )
    {
        $groups.Add($group)
    }
   
    Write-Host "       Default arguments"
    foreach ($field in $json.inputs | Where-Object {$_.groupName -eq $null})
    {
        DumpField -field $field | Out-File -FilePath $filepath -Append
    } 

    # other groups
    foreach( $group in $groups)
    {
        Write-Host "       Argument Group " $group.displayName
        "#### " + $group.displayName| Out-File -FilePath $filepath -Append 
        foreach ($field in $json.inputs | Where-Object {$_.groupName -eq $group.name})
        {
            DumpField -field $field | Out-File -FilePath $filepath -Append
        } 
    }
 }


#| Select-Object {$_.displayName} 