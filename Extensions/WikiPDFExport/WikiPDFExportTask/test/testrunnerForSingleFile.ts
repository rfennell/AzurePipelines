import {
    CloneWikiRepo
    } from "../src/GitWikiFuntions";

import {
    ExportPDF
    } from "../src/ExportFunctions";

function logInfo (msg: string) {
    console.log(msg);
}

function logError (msg: string) {
    console.log("\x1b[31m", msg);
}

// const singleFile = `${__dirname}\\..\\..\\..\\readme.md`;
const localFolder = `C:\\projects\\github\\AzurePipelines.wiki`;
const singleFile = `C:\\projects\\github\\AzurePipelines.wiki\\ArtifactDescription-Tasks.md`;
const outputFile = "c:\\tmp\\test\\new\\output.pdf";
console.log(`Current folder is ${__dirname}`);

ExportPDF (localFolder, singleFile , outputFile, "", logInfo, logError);