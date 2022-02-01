import {
    getSplitVersionParts,
    updateManifestFile,
    findFiles,
    extractVersion
} from "./ApplyVersionToManifestFunctions";

import tl = require("azure-pipelines-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var versionNameFormat = tl.getInput("VersionNameFormat");
var versionCodeFormat = tl.getInput("VersionCodeFormat");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");
var injectversion = tl.getBoolInput("Injectversion");
var injectversioncode = tl.getBoolInput("Injectversioncode");
var versionCode = tl.getInput("VersionCode");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Version Number Format: ${versionNameFormat}`);
console.log (`Version Code Format: ${versionCodeFormat}`);
console.log (`Version Code: ${versionCode}`);
console.log (`Inject Version: ${injectversion}`);
console.log (`Inject Version Code: ${injectversioncode}`);
console.log (`Output: Version Number Parameter Name: ${outputversion}`);

// Make sure path to source code directory is available
if (!fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
    process.exit(1);
}

// Apply the version to the assembly property files
var files = findFiles(path, filenamePattern, files);
console.log (`Found ${files.length} files to update.`);

const newVersion = extractVersion(injectversion, versionRegex, versionNumber);
console.log (`Extracted Version: ${newVersion}`);

const versionName = getSplitVersionParts(injectversion, versionRegex, versionNameFormat, newVersion);
console.log (`Version Name will be: ${versionName}`);

if (injectversioncode === false) {
    console.log(`Building the version code from the build number`);
    versionCode = getSplitVersionParts(injectversioncode, versionRegex, versionCodeFormat, newVersion);
} else {
    console.log(`Using the injected version code`);
}

if (parseInt(versionCode, 10) >= 2100000000) {
    tl.error(`Version Code of ${versionCode} is too long, must be below 2100000000 for submission to Google Play Store`);
    process.exit(1);
} else if (parseInt(versionCode, 0) === 0) {
    tl.error(`Version Code cannot be 0. Please ensure the value is greater than 0 and increments to unique numbers.`);

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
