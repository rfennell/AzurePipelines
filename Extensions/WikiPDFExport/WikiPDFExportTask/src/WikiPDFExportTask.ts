import tl = require("azure-pipelines-task-lib");
import * as fs from "fs";

import {
    ExportRun
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
var exeFolder = tl.getVariable("Agent.TempDirectory");

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [${password}]`);
console.log(`Variable: LocalPath [${localpath}]`);
console.log(`Variable: SingleFile [${singleFile}]`);
console.log(`Variable: OutputFile [${outputFile}]`);
console.log(`Variable: Branch [${branch}]`);
console.log(`Variable: InjectExtraHeader [${injectExtraHeader}]`);
console.log(`Variable: Exe Download Folder [${exeFolder}]`);

ExportRun(
    exeFolder,
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
    branch
);
