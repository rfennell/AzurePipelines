import tl = require("vsts-task-lib/task");
import fs = require("fs");
import jschardet = require("jschardet");


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

// List all files in a directory in Node.js recursively in a synchronous fashion
function findFiles (dir, filename , filelist) {
  var path = path || require('path');
  var fs = fs || require('fs'),
      files = fs.readdirSync(dir);
  filelist = filelist || [];
  files.forEach(function(file) {
    if (fs.statSync(path.join(dir, file)).isDirectory()) {
      filelist = findFiles(path.join(dir, file), filename, filelist);
    }
    else {
      if (file.toLowerCase().endsWith(filename.toLowerCase()))
      {
        filelist.push(path.join(dir, file));
      }
    }
  });
  return filelist;
};

// Make sure path to source code directory is available
if (!fs.existsSync(path))
{
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
} 

// Get and validate the version data
var regexp = new RegExp(versionRegex);
var versionData = regexp.exec(versionNumber);
if (!versionData)
{
    // extra check as we don't get zero size array but a null 
    tl.error(`Could not find version number data in ${versionNumber} that matches ${versionRegex}.`);
    process.exit(1);
}
switch(versionData.length)
{
   case 0:       
         // this is trapped by the null check above 
         tl.error(`Could not find version number data in ${versionNumber} that matches ${versionRegex}.`);
         process.exit(1);
   case 1:
        break;
   default: 
         tl.warning(`Found more than instance of version data in ${versionNumber}  that matches ${versionRegex}.`); 
         tl.warning(`Will assume first instance is version.`);
         break;
}

var newVersion = versionData[0]
console.log (`Extracted Version: ${newVersion}`);

// Apply the version to the assembly property files
var files = findFiles(`${path}`, filenamePattern, files); 


if (files.length>0) {

    console.log (`Will apply ${newVersion} to ${files.length} files.`);

    files.forEach(file => {
        var fileEncoding = jschardet.detect(fs.readFileSync(file));

        var filecontent = fs.readFileSync(file, fileEncoding.encoding);
        fs.chmodSync(file,"600");
        if (field && field.length > 0)
        {
            console.log (`Updating only the ${field} version`);
            regexp = new RegExp(`<${field}>${versionRegex}<\/${field}>`);
            newVersion = `<${field}>${newVersion}<\/${field}>`;
        } else {
            console.log (`Updating all version fields that match Regex ${versionRegex}`);
            regexp = new RegExp(versionRegex, "g"); // the g get all occurances
        }
        fs.writeFileSync(file,filecontent.toString().replace(regexp, newVersion),fileEncoding.encoding);
        console.log (`${file} - version applied`);
    });

    if (outputversion && outputversion.length > 0)
    {
        console.log (`Set the output variable '${outputversion}' with the value ${newVersion}`);
        tl.setVariable(outputversion, newVersion );
    }
}
else
{
    tl.warning("Found no files.");
}



