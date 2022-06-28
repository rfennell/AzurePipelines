import tl = require("azure-pipelines-task-lib/task");
import * as fs from "fs";

import {
    UpdateGitWikiFile,
    GetTrimmedUrl,
    GetProtocol
    } from "./GitWikiFuntions";

import {
    logInfo,
    logError,
    getSystemAccessToken
    }  from "./agentSpecific";

var repo = tl.getInput("repo");
var filename = tl.getInput("filename");
var localpath = tl.getInput("localpath");
var contentsInput = tl.getInput("contents");
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
var branch = tl.getInput("branch");
var injectExtraHeader = tl.getBoolInput("injectExtraHeader");
var retriesInput = tl.getInput("retries");
var trimLeadingSpecialChar = tl.getBoolInput("trimLeadingSpecialChar");
var fixLineFeeds = tl.getBoolInput("fixLineFeeds");
var fixSpaces = tl.getBoolInput("fixSpaces");
var insertLinefeed = tl.getBoolInput("insertLinefeed");
var prependEntryToOrderFile = tl.getBoolInput("prependEntryToOrderFile");
var updateOrderFile = tl.getBoolInput("updateOrderFile");
var orderFilePath = tl.getInput("orderFilePath");

// make sure the retries is a number

var retries = 5;
try {
    retries = Number(retriesInput);
} catch {
    console.log(`Count not parse the inputed retry count of ${retriesInput} set it to the default of ${retries} `);
}

console.log(`Variable: Repo [${repo}]`);
console.log(`Variable: Filename [${filename}]`);
console.log(`Variable: Contents [${contentsInput}]`);
console.log(`Variable: Commit Message [${message}]`);
console.log(`Variable: Git Username [${gitname}]`);
console.log(`Variable: Git Email [${gitemail}]`);
console.log(`Variable: Use Agent Token [${useAgentToken}]`);
console.log(`Variable: Replace File [${replaceFile}]`);
console.log(`Variable: Append to File [${appendToFile}]`);
console.log(`Variable: Username [${user}]`);
console.log(`Variable: Password [*****]`);
console.log(`Variable: LocalPath [${localpath}]`);
console.log(`Variable: Data Is File [${dataIsFile}]`);
console.log(`Variable: SourceFile [${sourceFile}]`);
console.log(`Variable: Tag Repo [${tagRepo}]`);
console.log(`Variable: Tag [${tag}]`);
console.log(`Variable: Branch [${branch}]`);
console.log(`Variable: InjectExtraHeader [${injectExtraHeader}]`);
console.log(`Variable: Retries [${retries}]`);
console.log(`Variable: trimLeadingSpecialChar [${trimLeadingSpecialChar}]`);
console.log(`Variable: fixLineFeeds [${fixLineFeeds}]`);
console.log(`Variable: fixSpaces [${fixSpaces}]`);
console.log(`Variable: insertLinefeed [${insertLinefeed}]`);
console.log(`Variable: updateOrderFile [${updateOrderFile}]`);
console.log(`Variable: prependEntryToOrderFile [${prependEntryToOrderFile}]`);
console.log(`Variable: orderFilePath [${orderFilePath}]`);

if (useAgentToken === true) {
    console.log(`Using OAUTH Agent Token, overriding username and password`);
    user = "buildagent";
    password = getSystemAccessToken();
}

var protocol = GetProtocol(repo, logInfo);
repo = GetTrimmedUrl(repo, logInfo);

var haveData = true;
var contents; // we late declare as it might be buffer or string
if (dataIsFile === true) {
    if (fs.existsSync(sourceFile)) {
        if (fixLineFeeds) {
            contents = fs.readFileSync(sourceFile, "utf8");
        } else {
            contents = fs.readFileSync(sourceFile);
        }
    } else {
        logError(`Cannot find the file ${sourceFile}`);
        haveData = false;
    }
} else {
    // we do this late copy so that we can use the same property for different encodings with a type clash
    contents = contentsInput;
}

if (haveData) {
    UpdateGitWikiFile(
        protocol,
        repo,
        localpath,
        user,
        password,
        gitname,
        gitemail,
        filename,
        message,
        contents,
        logInfo,
        logError,
        replaceFile,
        appendToFile,
        tagRepo,
        tag,
        injectExtraHeader,
        branch,
        retries,
        trimLeadingSpecialChar,
        fixLineFeeds,
        fixSpaces,
        insertLinefeed,
        updateOrderFile,
        prependEntryToOrderFile,
        orderFilePath);
}