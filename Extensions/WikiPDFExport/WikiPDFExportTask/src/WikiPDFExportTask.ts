import tl = require("azure-pipelines-task-lib");
import * as fs from "fs";

import {
    logInfo,
    logError,
    logWarning,
    getSystemAccessToken
    }  from "./agentSpecific";

import {
    ExportRun,
    GetExePath
    } from "./ExportFunctions";

var repo = tl.getInput("repo");
var localpath = tl.getInput("localpath");
var singleFile = tl.getInput("singleFile");
var outputFile = tl.getInput("outputFile");
var extraParams = tl.getInput("extraParameters");
var user = tl.getInput("user");
var password = tl.getInput("password");
var useAgentToken = tl.getBoolInput("useAgentToken");
var branch = tl.getInput("branch");
var injectExtraHeader = tl.getBoolInput("injectExtraHeader");
var cloneRepo = tl.getBoolInput("cloneRepo");
var overrideExePath = tl.getInput("overrideExePath");
var workingFolder = tl.getInput("downloadPath");
var rootExportPath = tl.getInput("rootExportPath");
var usePreRelease = tl.getBoolInput("usePreRelease");

// make sure that we support older configs where these two parameter were a single setting
if (!rootExportPath) {
    console.log(`Defaulting variable rootExportPath as not defined`);
    rootExportPath = localpath;
}

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [*****]`);
console.log(`Variable: LocalPath [${localpath}]`);
console.log(`Variable: rootExportPath [${rootExportPath}]`);
console.log(`Variable: SingleFile [${singleFile}]`);
console.log(`Variable: OutputFile [${outputFile}]`);
console.log(`Variable: Branch [${branch}]`);
console.log(`Variable: InjectExtraHeader [${injectExtraHeader}]`);
console.log(`Variable: OverrideExePath [${overrideExePath}]`);
console.log(`Variable: UsePreRelease [${usePreRelease}]`);
console.log(`Variable: DownloadPath [${workingFolder}]`);

var os = tl.getVariable("AGENT.OS");

GetExePath(
    overrideExePath,
    workingFolder,
    usePreRelease,
    os
).then((exePath) => {
    if (exePath.length > 0) {
        ExportRun(
            exePath,
            cloneRepo,
            localpath,
            singleFile,
            outputFile,
            extraParams,
            useAgentToken,
            repo,
            user,
            password,
            injectExtraHeader,
            branch,
            rootExportPath
        );
    } else {
        logError(`Cannot find the 'azuredevops-export-wiki' tool`);
    }
});
