import { findFiles,
         ProcessFile,
         getSplitVersionParts,
         extractVersion
} from "./AppyVersionToAngularFileFunctions";

import tl = require("azure-pipelines-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var field = tl.getInput("Field");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");
var injectversion = tl.getBoolInput("Injectversion");
var versionForJSONFileFormat = tl.getInput("versionForJSONFileFormat");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Version Format for JSON File: ${versionForJSONFileFormat}`);
console.log (`Field to update (all if empty): ${field}`);
console.log (`Inject Version: ${injectversion}`);

console.log (`Output: Version Number Parameter Name: ${outputversion}`);

// Make sure path to source code directory is available
if (!fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
}

// Get and validate the version data
const buildVersion = extractVersion(injectversion, versionRegex, versionNumber);
console.log (`Extracted Build Version: ${buildVersion}`);

const jsonVersion = getSplitVersionParts(injectversion, versionRegex, versionForJSONFileFormat, buildVersion);
console.log (`Angular Version Name will be: ${jsonVersion}`);

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
