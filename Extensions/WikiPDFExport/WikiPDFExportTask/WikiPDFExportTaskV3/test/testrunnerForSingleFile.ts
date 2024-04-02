import {
    ExportRun
    } from "../src/ExportFunctions";

function logInfo (msg: string) {
    console.log(msg);
}

function logError (msg: string) {
    console.log("\x1b[31m", msg);
}

// const singleFile = `${__dirname}\\..\\..\\..\\readme.md`;
const localpath = `C:\\projects\\github\\AzurePipelines.wiki`;
const rootExportPath = `C:\\projects\\github\\AzurePipelines.wiki`;
const singleFile = `C:\\projects\\github\\AzurePipelines.wiki\\ArtifactDescription-Tasks.md`;
const outputFile = "c:\\tmp\\test\\new\\output.pdf";
const injectExtraHeader = false;
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
