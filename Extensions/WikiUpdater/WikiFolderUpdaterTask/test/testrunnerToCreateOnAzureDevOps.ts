import {
    UpdateGitWikiFolder
    } from "../src/GitWikiFuntions";

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
const targetFolder = "folders";
const sourceFolder = "C:/projects/github/AzurePipelines/Extensions/WikiUpdater/WikiFolderUpdaterTask/testdata";
const filter = `**/*.md` ;
const message = "A message";
const gitname = "BuildProcess";
const gitemail = "Build@Process";
const replaceFile = true;
const appendFile = true;
const tagRepo = false;
const tag = "";
const injectExtraHeaders = false;
const branch = "";
const protocol = "https";
const retries = "5";

UpdateGitWikiFolder(protocol, repo, localpath, user, password, gitname, gitemail, targetFolder, message,  sourceFolder, filter, logInfo, logError, replaceFile, appendFile, tagRepo, tag, injectExtraHeaders, branch, retries);
