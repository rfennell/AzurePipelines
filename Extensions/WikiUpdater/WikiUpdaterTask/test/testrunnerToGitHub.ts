import {
    UpdateGitWikiFile
    } from "../src/GitWikiFuntions";

import {
    logDebug,
    logWarning,
    logInfo,
    logError
    }  from "../src/agentSpecific";

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

UpdateGitWikiFile(repo, localpath, user, password, gitname, gitemail, filename, message, contents, logInfo);
