import tl = require("vsts-task-lib/task");
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
var filename = tl.getInput("filename");
var localpath = tl.getInput("localpath");
var contents = tl.getInput("contents");
var message = tl.getInput("message");
var gitname = tl.getInput("gitname");
var gitemail = tl.getInput("gitemail");
var user = tl.getInput("user");
var password = tl.getInput("password");
var useAgentToken = tl.getBoolInput("useAgentToken");
var replaceFile = tl.getBoolInput("replaceFile");
var appendToFile = tl.getBoolInput("appendToFile");
var dataIsFile = tl.getBoolInput("dataIsFile");
var sourceFile = tl.getInput("sourceFile");
var tagRepo = tl.getBoolInput("tagRepo");
var tag = tl.getInput("tag");

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Filename [${filename}]`);
console.log(`Variable: Contents [${contents}]`);
console.log(`Variable: Commit Message [${message}]`);
console.log(`Variable: Git Username [${gitname}]`);
console.log(`Variable: Git Email [${gitemail}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Replace File [${replaceFile}]`);
console.log(`Variable: Append to File [${appendToFile}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [${password}]`);
console.log(`Variable: Localpath [${localpath}]`);
console.log(`Variable: Data Is File [${dataIsFile}]`);
console.log(`Variable: SoureFile [${sourceFile}]`);
console.log(`Variable: Tag Repo [${tagRepo}]`);
console.log(`Variable: Tag [${tag}]`);

if (useAgentToken === true) {
    console.log(`Using OAUTH Agent Token, overriding username and password`);
    user = "buildagent";
    password = getSystemAccessToken();
}

if (dataIsFile === true) {
    contents = fs.readFileSync(sourceFile, "utf8");
}

UpdateGitWikiFile(repo, localpath, user, password, gitname, gitemail, filename, message, contents, logInfo, logError, replaceFile, appendToFile, tagRepo, tag);