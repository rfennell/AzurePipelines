import {
    getSplitVersionParts,
    updateManifestFile,
    findFiles
} from "./ApplyVersionToManifestFunctions";

import tl = require("vsts-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var versionNameFormat = tl.getInput("VersionNameFormat");
var versionCodeFormat = tl.getInput("VersionCodeFormat");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Version Number Format: ${versionNameFormat}`);
console.log (`Version Code Format: ${versionCodeFormat}`);
console.log (`Output: Version Number Parameter Name: ${outputversion}`);

// Make sure path to source code directory is available
if (!fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
}

// Apply the version to the assembly property files
var files = findFiles(path, filenamePattern, files);
console.log (`Found ${files.length} files to update.`);

var regexp = new RegExp(versionRegex);
var versionData = regexp.exec(versionNumber);
if (!versionData) {
    // extra check as we don't get zero size array but a null
    tl.error(`Could not find version number data in ${versionNumber} that matches ${versionRegex}.`);
    process.exit(1);
}
switch (versionData.length) {
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

const newVersion = versionData[0];
console.log (`Extracted Version: ${newVersion}`);

const versionName = getSplitVersionParts(versionRegex, versionNameFormat, newVersion);
console.log (`Version Name will be: ${versionName}`);

const versionCode = getSplitVersionParts(versionRegex, versionCodeFormat, newVersion);
if (parseInt(versionCode, 10) >= 2100000000) {
    tl.error(`Version Code of ${versionCode} is too long, must be below 2100000000 for submission to Google Play Store`);
    process.exit(1);
} else {
    console.log (`Version Code will be ${versionCode}`);
}

if (files.length > 0) {
    console.log (`Will apply versionName: ${versionName} and versionCode: ${versionCode} to ${files.length} files.`);
    files.forEach(file => {
        updateManifestFile(file, versionCode, versionName);
    });
    if (outputversion && outputversion.length > 0) {
        console.log (`Set the output variable '${outputversion}' with the value ${newVersion}`);
        tl.setVariable(outputversion, newVersion );
    }
} else {
    tl.warning("Found no files.");
}
