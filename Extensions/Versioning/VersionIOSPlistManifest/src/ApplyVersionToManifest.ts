import {
    getSplitVersionParts,
    updateManifestFile,
    findFiles,
    extractVersion
} from "./ApplyVersionToManifestFunctions";

import tl = require("azure-pipelines-task-lib/task");
import fs = require("fs");

var path = tl.getInput("Path");
var versionRegex = tl.getInput("VersionRegex");
var versionNameFormat = tl.getInput("VersionNameFormat");
var CFBundleVersionFormat = tl.getInput("CFBundleVersionFormat");
var CFBundleShortVersionStringFormat = tl.getInput("CFBundleShortVersionStringFormat");

var outputversion = tl.getInput("outputversion");

var filenamePattern = tl.getInput("FilenamePattern");

var injectversion = tl.getBoolInput("Injectversion");
var InjectCFBundleVersion = tl.getBoolInput("InjectCFBundleVersion");
var InjectCFBundleShortVersionString = tl.getBoolInput("InjectCFBundleShortVersionString");

var versionNumber = tl.getInput("VersionNumber");

console.log (`Source Directory:  ${path}`);
console.log (`Filename Pattern: ${filenamePattern}`);
console.log (`Version Number/Build Number: ${versionNumber}`);
console.log (`Version Filter to extract build number: ${versionRegex}`);
console.log (`Version Number Format: ${versionNameFormat}`);
console.log (`CFBundleVersion Format: ${CFBundleVersionFormat}`);
console.log (`CFBundleShortVersionString Format: ${CFBundleShortVersionStringFormat}`);
console.log (`Injected versionNumber: ${versionNumber}`);
console.log (`Inject Version: ${injectversion}`);

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
console.log (`Extracted Version from Build Number: ${newVersion}`);

const CFBundleVersion = getSplitVersionParts(injectversion, versionRegex, CFBundleVersionFormat, newVersion);
console.log (`CFBundleVersion will be: ${CFBundleVersion}`);

const CFBundleShortVersionString = getSplitVersionParts(injectversion, versionRegex, CFBundleShortVersionStringFormat, newVersion);
console.log (`CFBundleShortVersionString will be: ${CFBundleShortVersionString}`);

if (files.length > 0) {
    console.log (`Will apply CFBundleVersion: ${CFBundleVersion} and CFBundleShortVersionString: ${CFBundleShortVersionString} to ${files.length} files.`);
    files.forEach(file => {
        updateManifestFile(
            file,
            {
                "CFBundleVersion": CFBundleVersion,
                "CFBundleShortVersionString": CFBundleShortVersionString
            });
    });
    if (outputversion && outputversion.length > 0) {
        console.log (`Set the output variable '${outputversion}' with the value ${newVersion}`);
        tl.setVariable(outputversion, newVersion );
    }
} else {
    tl.warning("Found no files.");
}
