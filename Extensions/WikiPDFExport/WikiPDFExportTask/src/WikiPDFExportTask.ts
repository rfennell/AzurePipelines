import tl = require("azure-pipelines-task-lib");
import * as fs from "fs";

import {
    CloneWikiRepo,
    GetTrimmedUrl,
    GetProtocol
    } from "./GitWikiFuntions";

import {
    ExportPDF
    } from "./ExportFunctions";

import {
    logInfo,
    logError,
    getSystemAccessToken
    }  from "./agentSpecific";

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

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [${password}]`);
console.log(`Variable: LocalPath [${localpath}]`);
console.log(`Variable: SingleFile [${singleFile}]`);
console.log(`Variable: OutputFile [${outputFile}]`);
console.log(`Variable: Branch [${branch}]`);
console.log(`Variable: InjectExtraHeader [${injectExtraHeader}]`);

if (cloneRepo) {
    console.log(`Cloning Repo`);
    if (useAgentToken === true) {
        console.log(`Using OAUTH Agent Token, overriding username and password`);
        user = "buildagent";
        password = getSystemAccessToken();
    }

    var protocol = GetProtocol(repo, logInfo);
    repo = GetTrimmedUrl(repo, logInfo);
    CloneWikiRepo(protocol, repo, localpath, user, password, logInfo, logError, injectExtraHeader, branch);
}

if (singleFile && singleFile.length > 0) {
    console.log(`A filename ${singleFile} has been passed so only processing that file `);
    ExportPDF ("azuredevops-export-wiki.exe", localpath, singleFile, outputFile, extraParams,  logInfo, logError);
} else  {
    console.log(`No filename has been passed so cloning the repo `);
    ExportPDF ("azuredevops-export-wiki.exe", localpath, "" , outputFile, extraParams, logInfo, logError);
}