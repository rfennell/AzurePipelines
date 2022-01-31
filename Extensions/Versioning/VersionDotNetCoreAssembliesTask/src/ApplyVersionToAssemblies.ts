import { findFiles,
         ProcessFile,
         stringToBoolean,
         extractVersion,
         SplitSDKName
  } from "./AppyVersionToAssembliesFunctions";

import tl = require("azure-pipelines-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var field = tl.getInput("Field");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");
var addDefault = tl.getInput("AddDefault");
var injectversion = tl.getBoolInput("Injectversion");
var sdknames = tl.getInput("SDKNames");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Field to update (all if empty): ${field}`);
console.log (`Add default field (all if empty): ${addDefault}`);
console.log (`Output: Version Number Parameter Name: ${outputversion}`);
console.log (`Inject Version: ${injectversion}`);
console.log (`SDK names: ${sdknames}`);

// Make sure path to source code directory is available
if (!fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
}

// Get and validate the version data
var newVersion = extractVersion(injectversion, versionRegex, versionNumber);
console.log (`Extracted Version: ${newVersion}`);

// Apply the version to the assembly property files
var sdkArray = SplitSDKName(sdknames);
var files = findFiles(`${path}`, filenamePattern, files, sdkArray);

if (files.length > 0) {

    console.log (`Will apply ${newVersion} to ${files.length} files.`);

    files.forEach(file => {
        ProcessFile(file, field, newVersion, stringToBoolean(addDefault));
    });

    if (outputversion && outputversion.length > 0) {
        console.log (`Set the output variable '${outputversion}' with the value ${newVersion}`);
        tl.setVariable(outputversion, newVersion );
    }
} else {
    tl.warning("Found no files.");
}
