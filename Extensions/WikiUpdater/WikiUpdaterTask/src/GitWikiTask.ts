import tl = require("vsts-task-lib/task");

import {
    UpdateGitWikiFile
    } from "./GitWikiFuntions";

import {
    logDebug,
    logWarning,
    logInfo,
    logError
    }  from "./agentSpecific";

function getSystemAccessToken(): string {
    tl.debug("Getting credentials the agent is running as");
    var auth = tl.getEndpointAuthorization("SYSTEMVSSCONNECTION", false);
    if (auth.scheme === "OAuth") {
        tl.debug("Found an OAUTH token");
        return auth.parameters["AccessToken"];
    } else {
        tl.warning(tl.loc("BuildCredentialsWarn"));
    }
}

var repo = tl.getInput("repo");
var filename = tl.getInput("filename");
var localpath = tl.getInput("localpath");
var contents = tl.getInput("contents");
var message = tl.getInput("message");
var gitname = tl.getInput("gitname");
var gitemail = tl.getInput("gitemail");
var user = tl.getInput("user");
var password = tl.getInput("password");
var useAgentToken = tl.getBoolInput("useAgentToken");

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Filename [${filename}]`);
console.log(`Variable: Contents [${contents}]`);
console.log(`Variable: Commit Message [${message}]`);
console.log(`Variable: Git Username [${gitname}]`);
console.log(`Variable: Git Email [${gitemail}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [${password}]`);
console.log(`Variable: Localpath [${localpath}]`);

if (useAgentToken === true) {
    console.log(`Using OAUTH Agent Token, overriding username and password`);
    user = "buildagent";
    password = getSystemAccessToken();
}

UpdateGitWikiFile(repo, localpath, user, password, gitname, gitemail, filename, message, contents, logInfo, logError);