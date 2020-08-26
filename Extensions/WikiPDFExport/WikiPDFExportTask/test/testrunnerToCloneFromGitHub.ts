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

// GitHub always needs the user ID
const user = "rfennell";
// If using 2FA this must be a PAT
const password = "<PAT>";
const repo = "github.com/rfennell/demorepo.wiki";

const localpath = "c:\\tmp\\test\\repo";
const injectExtraHeaders = false;
const branch = "";
const protocol = "https";
const outputFile = "c:\\tmp\\test\\output.pdf";

CloneWikiRepo(protocol, repo, localpath, user, password, logInfo, logError, injectExtraHeaders, branch);
console.log(`Current folder is ${__dirname}`);
ExportPDF (`${__dirname}\\..\\..\\task\\azuredevops-export-wiki.exe`, localpath, "" , outputFile, "", logInfo, logError);