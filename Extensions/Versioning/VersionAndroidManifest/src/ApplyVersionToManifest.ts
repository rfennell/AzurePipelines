import {
    getVersionName,
    getVersionCode,
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
var files = findFiles(`${path}`, filenamePattern, files);
console.log (`Found ${files.count} to update.`);

// Get and validate the version data
var versionData = versionRegex.match(versionNumber);
if (versionData.length === 0) {
    tl.error (`Could not find version number data in ${versionNumber}.`);
    process.exit(1);
} else if (versionData.length > 1) {
    tl.warning (`Found more than instance of version data in ${versionNumber}.`);
    tl.warning ("Will assume first instance is version.");
}

const newVersion = versionData[0];
console.log (`Extracted Version: ${newVersion}`);

const versionName = getVersionName(versionNameFormat, newVersion);
console.log (`Version Name will be: ${versionName}`);

const versionCode = getVersionCode(versionCodeFormat, newVersion);
console.log (`Version Code will be ${versionCode}`);

if (files.length > 0) {
    console.log (`Will apply versionName: ${versionName} and versionCode: ${versionCode} $to ${files.length} files.`);
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
