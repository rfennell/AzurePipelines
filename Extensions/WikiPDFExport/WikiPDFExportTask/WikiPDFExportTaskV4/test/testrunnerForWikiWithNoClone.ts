import {
    ExportRun
    } from "../src/ExportFunctions";

function logInfo (msg: string) {
    console.log(msg);
}

function logError (msg: string) {
    console.log("\x1b[31m", msg);
}

const localpath = `${__dirname}\\..\\..\\..\\..\\..\\..\\AzurePipelines.wiki`;
const rootExportPath = `${__dirname}\\..\\..\\..\\..\\..\\..\\AzurePipelines.wiki`;

const outputFile = "c:\\tmp\\test\\output.pdf";
const injectExtraHeader = false;
const singleFile = "";
const extraParams = "";
const useAgentToken = false;
const cloneRepo = false;
const user = "";
const password = "";
const repo = "";
const branch = "";
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
