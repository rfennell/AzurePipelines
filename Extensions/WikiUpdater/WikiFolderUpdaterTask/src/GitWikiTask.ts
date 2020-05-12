import tl = require("azure-pipelines-task-lib/task");
import * as fs from "fs";

import {
    UpdateGitWikiFile
    } from "./GitWikiFuntions";

import {
    logInfo,
    logError,
    getSystemAccessToken
    }  from "./agentSpecific";

var repo = tl.getInput("repo");
var targetFolder = tl.getInput("targetFolder");
var localpath = tl.getInput("localpath");
var message = tl.getInput("message");
var gitname = tl.getInput("gitname");
var gitemail = tl.getInput("gitemail");
var user = tl.getInput("user");
var password = tl.getInput("password");
var useAgentToken = tl.getBoolInput("useAgentToken");
var replaceFile = tl.getBoolInput("replaceFile");
var appendToFile = tl.getBoolInput("appendToFile");
var sourceFolder = tl.getInput("sourceFolder");
var filter = tl.getInput("filter");
var tagRepo = tl.getBoolInput("tagRepo");
var tag = tl.getInput("tag");
var branch = tl.getInput("branch");
var injectExtraHeader = tl.getBoolInput("injectExtraHeader");

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: TargetFolder [${targetFolder}]`);
console.log(`Variable: Commit Message [${message}]`);
console.log(`Variable: Git Username [${gitname}]`);
console.log(`Variable: Git Email [${gitemail}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Replace File [${replaceFile}]`);
console.log(`Variable: Append to File [${appendToFile}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [${password}]`);
console.log(`Variable: Localpath [${localpath}]`);
console.log(`Variable: SourceFolder [${sourceFolder}]`);
console.log(`Variable: Filter [${filter}]`);
console.log(`Variable: Tag Repo [${tagRepo}]`);
console.log(`Variable: Tag [${tag}]`);
console.log(`Variable: Branch [${branch}]`);
console.log(`Variable: InjectExtraHeader [${injectExtraHeader}]`);

if (useAgentToken === true) {
    console.log(`Using OAUTH Agent Token, overriding username and password`);
    user = "buildagent";
    password = getSystemAccessToken();
}

UpdateGitWikiFile(repo, localpath, user, password, gitname, gitemail, targetFolder, message, sourceFolder, filter, logInfo, logError, replaceFile, appendToFile, tagRepo, tag, injectExtraHeader, branch);