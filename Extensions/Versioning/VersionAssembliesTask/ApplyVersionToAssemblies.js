"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const tl = require("vsts-task-lib/task");
const fs = require("fs");
var path = tl.getInput("Path");
var versionNumber = tl.getInput("VersionNumber");
var versionRegex = tl.getInput("VersionRegex");
var field = tl.getInput("Field");
var outputversion = tl.getInput("outputversion");
var filenamePattern = tl.getInput("FilenamePattern");
console.log(`Source Directory:  ${path}`);
console.log(`Filename Pattern: ${filenamePattern}`);
console.log(`Version Number/Build Number: ${versionNumber}`);
console.log(`Version Filter to extract build number: ${versionRegex}`);
console.log(`Field to update (all if empty): ${field}`);
console.log(`Output: Version Number Parameter Name: ${outputversion}`);
// Make sure path to source code directory is available
if (fs.existsSync(path)) {
    tl.error(`Source directory does not exist: ${path}`);
}
else {
}
