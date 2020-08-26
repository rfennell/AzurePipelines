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

const wikiPath = `${__dirname}\\..\\..\\..\\..\\..\\..\\AzurePipelines.wiki`;
const outputFile = "c:\\tmp\\test\\output.pdf";

console.log(`Current folder is ${__dirname}`);
ExportPDF (`${__dirname}\\..\\..\\task\\azuredevops-export-wiki.exe`, wikiPath, "" , outputFile, "", logInfo, logError);