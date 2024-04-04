import simpleGit, { SimpleGit, CleanOptions } from "simple-git";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";
import * as process from "process";
import { logDebug, logWarning } from "./agentSpecific";
import { SSL_OP_CIPHER_SERVER_PREFERENCE, SSL_OP_LEGACY_SERVER_CONNECT } from "constants";

// A wrapper to make sure that directory delete is handled in sync
function rimrafPromise(localpath) {
    return new Promise((resolve, reject) => {
        rimraf(localpath, () => {
            resolve(0);
        }, (error) => {
            reject(error);
        });
    });
}

function mkDirByPathSync(targetDir, { isRelativeToScript = false } = {}) {
    const sep = path.sep;
    const initDir = path.isAbsolute(targetDir) ? sep : "";
    const baseDir = isRelativeToScript ? __dirname : ".";

    return targetDir.split(sep).reduce((parentDir, childDir) => {
        const curDir = path.resolve(baseDir, parentDir, childDir);
        try {
            fs.mkdirSync(curDir);
        } catch (err) {
            if (err.code === "EEXIST") { // curDir already exists!
                return curDir;
            }

            // To avoid `EISDIR` error on Mac and `EACCES`-->`ENOENT` and `EPERM` on Windows.
            if (err.code === "ENOENT") { // Throw the original parentDir error on curDir `ENOENT` failure.
                throw new Error(`EACCES: permission denied, mkdir '${parentDir}'`);
            }

            const caughtErr = ["EACCES", "EPERM", "EISDIR"].indexOf(err.code) > -1;
            if (!caughtErr || caughtErr && curDir === path.resolve(targetDir)) {
                throw err; // Throw if it's just the last created dir.
            }
        }

        return curDir;
    }, initDir);
}

export function GetWorkingFolder(localpath, filename, logInfo): any {
    var pathParts = path.parse(filename);
    if (pathParts.dir && pathParts.dir !== "/" && pathParts.dir !== "\\") {
        var targetPath = path.join(localpath, path.join(pathParts.dir));
        if (!fs.existsSync(targetPath)) {
            logInfo(`Creating the directory ${targetPath}`);
            mkDirByPathSync(targetPath);
        }
        return targetPath;
    } else {
        logInfo(`No sub-directory passed change to ${localpath}`);
        return localpath;
    }
}

export function GetWorkingFile(filename, logInfo): any {
    var pathParts = path.parse(filename);
    var name = pathParts.base;
    logInfo(`Working file name is ${name}`);
    return name;
}

export function GetProtocol(url: string, logInfo): string {
    var protocol = "https";
    logInfo(`The provided repo URL is ${url}`);
    if (url.indexOf("://") !== -1) {
        protocol = url.substr(0, url.indexOf("//") - 1);
    }
    logInfo(`The protocol is ${protocol}`);
    return protocol;
}

export function GetTrimmedUrl(url: string, logInfo): string {
    var fixedUrl = url;
    logInfo(`The provided repo URL is ${fixedUrl}`);
    if (fixedUrl.indexOf("://") !== -1) {
        logInfo(`Removing leading http:// or https:// block`);
        fixedUrl = fixedUrl.substr(fixedUrl.indexOf("://") + 3);
    }
    if (fixedUrl.indexOf("@") !== -1) {
        logInfo(`Removing leading username@ block`);
        fixedUrl = fixedUrl.substr(fixedUrl.indexOf("@") + 1);
    }
    logInfo(`Trimmed the URL to ${fixedUrl}`);
    return fixedUrl;
}

export async function UpdateGitWikiFile(
    protocol,
    repo,
    localpath,
    user,
    password,
    gitName,
    gitEmail,
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
    sslBackend,
    branch,
    maxRetries,
    trimLeadingSpecialChar,
    fixLineFeeds,
    fixSpaces,
    insertLinefeed,
    updateOrderFile,
    prependEntryToOrderFile,
    orderFilePath,
    injecttoc,
    mode) {
    const git = simpleGit();

    // show error if content is null
    if (!contents) {
        logError(`The new content is null, so cannot be used to update the wiki`);
        return;
    }

    let remote = "";
    let logremote = ""; // used to make sure we hide the password in logs
    var extraHeaders = [];  // Add handling for #613

    if (injectExtraHeader) {
        remote = `${protocol}://${repo}`;
        logremote = remote;
        extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
        if (sslBackend) {
            extraHeaders.push(`-c http.sslbackend=${sslBackend}`);
            logInfo(`Injecting http.sslbackend configuration using parameter -c http.sslbackend=${sslBackend}`);
        }
        logInfo(`Injecting the authentication via the clone command using paramter -c http.extraheader='AUTHORIZATION: bearer ***'`);
    } else {
        if (password === null) {
            remote = `${protocol}://${repo}`;
            logremote = remote;
        } else if (user === null) {
            remote = `${protocol}://${password}@${repo}`;
            logremote = `${protocol}://***@${repo}`;
        } else {
            remote = `${protocol}://${user}:${password}@${repo}`;
            logremote = `${protocol}://${user}:***@${repo}`;
        }
    }

    logInfo(`URL used ${logremote}`);

    try {
        if (fs.existsSync(localpath)) {
            await rimrafPromise(localpath);
        }
        logInfo(`Cleaned ${localpath}`);

        await git.clone(remote, localpath, extraHeaders);
        logInfo(`Cloned ${repo} to ${localpath}`);

        await git.cwd(localpath);
        logInfo(`Setting GitConfig Name:${gitName} Email:${gitEmail}`);
        await git.addConfig("user.name", gitName);
        await git.addConfig("user.email", gitEmail);
        logInfo(`Set GIT values in ${localpath}`);

        // issue 969 - remove spaces
        if (fixSpaces) {
            var name = GetWorkingFile(filename, logInfo);
            if (name.includes(" ")) {
                logInfo(`The target filename contains spaces which are not valid in WIKIs filename '${name}'`);
                // we only update the filename portion, not the path. Need to use regex else only first instance changed
                filename = filename.replace(name, name.replace(/\s/g, "-"));
                logInfo(`Update filename '${filename}'`);
            }
        }

        // move to the working folder
        var workingPath = GetWorkingFolder(localpath, filename, logInfo);
        process.chdir(workingPath);

        if (branch) {
            logInfo(`Checking out the requested branch ${branch}`);
            await git.checkout(branch);
        }

        // do git pull just in case the clone was slow and there have been updates since
        // this is to try to reduce concurrency issues
        await git.pull();
        logInfo(`Git Pull, prior to local commits, in case of post clone updates to the repo from other users`);

        // we need to change any encoded
        var workingFile = GetWorkingFile(filename, logInfo);
        if (replaceFile) {
            if (fixLineFeeds) {
                logInfo(`Created the '${workingFile}' in '${workingPath}' - fixing line-endings`);
                fs.writeFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
            } else {
                logInfo(`Created the '${workingFile}' in '${workingPath}' - without fixing line-endings`);
                fs.writeFileSync(workingFile, contents);
            }
        } else {
            if (appendToFile) {
                if (insertLinefeed) {
                    // fix for #988 trailing new lines are trimmed from inline content
                    logDebug(`Injecting linefeed between existing and new content`);
                    fs.appendFileSync(workingFile, "\r\n");
                }
                // fix for #826 where special characters get added between the files being appended
                fs.appendFileSync(workingFile, FixedFormatOfNewContent(contents, trimLeadingSpecialChar));
                logInfo(`Appended to the ${workingFile} in ${workingPath}`);
            } else {
                var oldContent = "";
                if (fs.existsSync(workingFile)) {
                    oldContent = fs.readFileSync(workingFile, "utf8");
                }
                if (injecttoc) {
                    logDebug(`Replacing old [[_TOC_]] with a new one at the top of the pre-pended content`);
                    oldContent = oldContent.replace("[[_TOC_]]", "");  // we the single existing TOC ignoring the line feeds following
                    fs.writeFileSync(workingFile, "[[_TOC_]]\r\n\r\n"); // we add a 2nd feed, as blank line is required after the TOC
                    logDebug(`Appending new content after [[_TOC_]]`);
                    fs.appendFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
                } else {
                    logDebug(`Writing new content`);
                    fs.writeFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
                }

                if (insertLinefeed) {
                    // fix for #988 trailing new lines are trimmed from inline content
                    logDebug(`Injecting linefeed between existing and new content`);
                    fs.appendFileSync(workingFile, "\r\n");
                }
                logDebug(`Appending old content`);
                fs.appendFileSync(workingFile, FixedFormatOfNewContent(oldContent, trimLeadingSpecialChar));
                logInfo(`Prepending to the ${workingFile} in ${workingPath}`);
            }
        }

        await git.add(filename);
        logInfo(`Added ${filename} to repo ${localpath}`);

        if (updateOrderFile) {

            var orderFile = `${localpath}/.order`;
            if (orderFilePath && orderFilePath.length > 0) {
                orderFile = `${localpath}/${orderFilePath}/.order`;
            }

            logInfo(`Using the file - ${orderFile}`);

            // we need the name without the extension and the folder path
            var entry = path.basename(filename.replace(/.md/i, ""));

            if (fs.existsSync(orderFile)) {
                logInfo(`Attempting to updating the existing .order file`);
                oldContent = fs.readFileSync(orderFile, "utf8");
            } else {
                logInfo(`Attempting to create a new .order file`);
                oldContent = "";
            }

            // we edit the order file if the new entry is not already in the file
            if (oldContent.includes(entry)) {
                logInfo(`The entry '${entry}' already exists in the .order file, skipping update`);
            } else {
                if (prependEntryToOrderFile) {
                    // prepending the entry
                    if (fs.existsSync(orderFile)) {
                        oldContent = fs.readFileSync(orderFile, "utf8");
                        // as we are pre-pending we alway need a line feed
                        fs.writeFileSync(orderFile, `${entry}\r\n`);
                        fs.appendFileSync(orderFile, oldContent);
                        logInfo(`Preppending entry to the .order file`);
                    } else {
                        fs.writeFileSync(orderFile, `${entry}`);
                        logInfo(`Creating .order file as it does not exist`);
                    }
                } else {
                    // appending the entry
                    if (fs.existsSync(orderFile)) {
                        // check the content to make sure we have the required line feed
                        oldContent = fs.readFileSync(orderFile, "utf8");
                        if (!oldContent.endsWith("\r\n")) {
                            fs.appendFileSync(orderFile, "\r\n");
                        }
                    }
                    fs.appendFileSync(orderFile, entry);
                    logInfo(`Appending entry to the .order file`);
                }

                await git.add(orderFile);
                logInfo(`Added .order file to repo ${localpath}`);

            }
        }

        logDebug(`Committing the changes with the message: ${message}`);

        var summary = await git.commit(message);
        if (summary.commit.length > 0) {
            logInfo(`Committed file "${localpath}" with message "${message}" as SHA ${summary.commit}`);

            if (maxRetries < 1) {
                maxRetries = 1;
                logInfo(`Setting max retries to 1 and it must be a positive value`);
            }
            for (let index = 1; index <= maxRetries; index++) {
                try {
                    logInfo(`Attempt ${index} - Push to ${repo}`);
                    await git.push();
                    logInfo(`Push completed`);
                    break;
                } catch (err) {
                    if (index < maxRetries) {
                        logInfo(`Push failed, will retry up to ${maxRetries} times after updating the local repo with the latest changes from the server`);
                        logInfo(err);
                        sleep(1000);
                        switch (mode) {
                            case "Rebase":
                                logInfo(`Pulling with --rebase=true option to get updates from other users`);
                                if (!branch) {
                                    logError(`Rebase requested, but no branch passed in as a parameter`);
                                    return;
                                }
                                await git.pull("origin", branch , { "--rebase": "true" });
                                break;
                            default: // Pull
                                logInfo(`Pull to get updates from other users`);
                                await git.pull();
                                break;
                        }
                    } else {
                        logInfo(`Reached the retry limit`);
                        logError(err);
                        return;
                    }
                }
            }

            if (tagRepo) {
                if (tag.length > 0) {
                    logInfo(`Adding tag ${tag}`);
                    await git.addTag(tag);
                    await git.pushTags();
                } else {
                    logWarning(`Requested to add tag, but no tag passed`);
                }
            }
        } else {
            logInfo(`No commit was performed as the new file has no changes from the existing version`);
        }

    } catch (error) {
        logError(error);
    }

}

function FixedFormatOfNewContent(contents: string, trimLeadingSpecialChar: boolean): string {
    // sort out the newlines
    var fixedContents: string = contents.replace(/`n/g, "\r\n");
    // fix for #826 where special characters get added between the files being appended
    // 65279 is the Unicode Character 'ZERO WIDTH NO-BREAK SPACE'
    if (trimLeadingSpecialChar && fixedContents.charCodeAt(0) === 65279) {
        fixedContents = fixedContents.substr(1);
    }
    return fixedContents;
}

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}