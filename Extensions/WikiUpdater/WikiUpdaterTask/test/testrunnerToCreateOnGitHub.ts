import {
    UpdateGitWikiFile
    } from "../src/GitWikiFuntions";

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
const filename = "page.md";
const contents = `Some text ${new Date().toString()}` ;
const message = "A message";
const gitname = "BuildProcess";
const gitemail = "Build@Process";
const replaceFile = true;
const appendFile = true;
const tagRepo = false;
const tag = "";
const branch = "";
const injectExtraHeaders = false;
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
