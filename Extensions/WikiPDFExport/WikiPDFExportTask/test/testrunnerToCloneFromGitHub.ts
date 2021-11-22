import {
    ExportRun
    } from "../src/ExportFunctions";

function logInfo (msg: string) {
    console.log(msg);
}

function logError (msg: string) {
    console.log("\x1b[31m", msg);
}

// GitHub always needs the user ID
const user = "rfennell";
// If using 2FA this must be a PAT
const password = "<PAT>";
const repo = "github.com/rfennell/demorepo.wiki";

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
