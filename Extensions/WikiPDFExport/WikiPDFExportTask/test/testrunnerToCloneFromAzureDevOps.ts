import {
    ExportRun
    } from "../src/ExportFunctions";

import {
    ExportPDF
    } from "../src/ExportFunctions";

function logInfo (msg: string) {
    console.log(msg);
}

function logError (msg: string) {
    console.log("\x1b[31m", msg);
}

// if using a PAT this is the instance name
const user = "richardfennell";
// If not using basic auth (bad) this must be a PAT
const password = "<PAT>";

const repo = "dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki";
const localpath = "c:\\tmp\\test\\repo";
const rootExportPath = "c:\\tmp\\test\\repo";
const injectExtraHeaders = false;
const branch = "";
const protocol = "https";
const outputFile = "c:\\tmp\\test\\output.pdf";
const injectExtraHeader = false;
const singleFile = "";
const extraParams = "";
const useAgentToken = false;
const cloneRepo = true;
const exePath = "..\\testdata\\azuredevops-export-wiki.exe";
const isWindows = true;

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
