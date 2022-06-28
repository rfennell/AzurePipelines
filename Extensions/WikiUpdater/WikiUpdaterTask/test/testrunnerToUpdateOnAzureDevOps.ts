import {
    UpdateGitWikiFile
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

const repo = "dev.azure.com/richardfennell/Git%20project/_git/WikiRepo";
const localpath = "c:\\tmp\\test\\repo";
const filename = "page.md";
const contents = `Some text ${new Date().toString()}` ;
const message = "A message";
const gitname = "BuildProcess";
const gitemail = "Build@Process";
const replaceFile = false;
const appendFile = true;
const tagRepo = false;
const tag = "";
const injectExtraHeaders = false;
const branch = "";
const protocol = "https";
const retries = 5;
const trimLeadingSpecialChar = true;
const fixLineFeeds = true;
const fixSpaces = true;
const insertLinefeed = false;
const updateOrderFile = false;
const prependEntryToOrderFile = false;
const orderFilePath = "";

UpdateGitWikiFile(protocol, repo, localpath, user, password, gitname, gitemail, filename, message, contents, logInfo, logError, replaceFile, appendFile, tagRepo, tag, injectExtraHeaders, branch, retries, trimLeadingSpecialChar, fixLineFeeds, fixSpaces, insertLinefeed, updateOrderFile, prependEntryToOrderFile, orderFilePath);
