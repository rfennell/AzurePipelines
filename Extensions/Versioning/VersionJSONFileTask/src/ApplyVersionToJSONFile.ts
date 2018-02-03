import { findFiles,
         ProcessFile,
         getSplitVersionParts
  } from "./AppyVersionToJSONFileFunctions";

import tl = require("vsts-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var field = tl.getInput("Field");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");
var versionForJSONFileFormat = tl.getInput("versionForJSONFileFormat");
var useBuildNumberDirectly = tl.getBoolInput("useBuildNumberDirectly");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Use Build Number Directly: ${useBuildNumberDirectly}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Version Format for JSON File: ${versionForJSONFileFormat}`);
console.log (`Field to update (all if empty): ${field}`);
console.log (`Output: Version Number Parameter Name: ${outputversion}`);

// Make sure path to source code directory is available
if (!fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
}

// work out if we need to extract the verson from the build
let jsonVersion = versionNumber; // set the default value
if (useBuildNumberDirectly === false) {
    // Get and validate the version data
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

    console.log (`Extracting version from the build number`);
    var buildVersion = versionData[0];
    console.log (`Extracted Build Version: ${buildVersion}`);
    jsonVersion = getSplitVersionParts(versionRegex, versionForJSONFileFormat, buildVersion);
} else {
    console.log (`Using the provided build number without any further processing`);
}
console.log (`JSON Version Name will be: ${jsonVersion}`);

// Apply the version to the assembly property files
var files = findFiles(`${path}`, filenamePattern, files);

if (files.length > 0) {

    console.log (`Will apply ${jsonVersion} to ${files.length} files.`);

    files.forEach(file => {
        ProcessFile(file, field, jsonVersion);
    });

    if (outputversion && outputversion.length > 0) {
        console.log (`Set the output variable '${outputversion}' with the value ${jsonVersion}`);
        tl.setVariable(outputversion, jsonVersion );
    }
} else {
    tl.warning("Found no files.");
}
