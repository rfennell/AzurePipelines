import tl = require("vsts-task-lib/task");
import fs = require("fs");


var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var field = tl.getInput("Field");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Field to update (all if empty): ${field}`);
console.log (`Output: Version Number Parameter Name: ${outputversion}`);

// Make sure path to source code directory is available
if (fs.existsSync(path))
{
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
} 

// Get and validate the version data
var regexp = new RegExp(versionRegex);
var versionData = regexp.exec(versionNumber);
switch(versionData.length)
{
   case 0:        
         tl.error(`Could not find version number data in ${versionNumber}.`);
         process.exit(1);
   case 1:
        break;
   default: 
         tl.warning(`Found more than instance of version data in ${versionNumber}.`); 
         tl.warning(`Will assume first instance is version.`);
         break;
}

var newVersion = versionData[0]
console.log (`Extracted Version: ${newVersion}`);

// Apply the version to the assembly property files
var files = Get-ChildItem path -recurse -include "*Properties*","My Project" | 
    Where-Object { $_.PSIsContainer } | 
    foreach { Get-ChildItem -Path $_.FullName -Recurse -include $FilenamePattern }

   console.log (`Will apply $NewVersion to ${files.count} files.`);

    foreach (file in files) {
        $FileEncoding = Get-FileEncoding -Path $File.FullName
        $filecontent = Get-Content -Path $file.Fullname
        attrib $file -r
        if ([string]::IsNullOrEmpty($field))
        {
            console.log ("Updating all version fields");
            $filecontent -replace $VersionRegex, $NewVersion | Out-File $file -Encoding $FileEncoding
        } else {
            console.log ("Updating only the '$field' version");
            $filecontent -replace "$field\(`"$VersionRegex", "$field(`"$NewVersion" | Out-File $file -Encoding $FileEncoding
        }
        
        Write-Verbose "$file - version applied"
    }
    Write-Verbose "Set the output variable '$outputversion' with the value $NewVersion"
    Write-Host "##vso[task.setvariable variable=$outputversion;]$NewVersion"
}
else
{
    Write-Warning "Found no files."
}