import simpleGit, { SimpleGit, CleanOptions } from "simple-git";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";
import * as process from "process";
import { logWarning } from "./agentSpecific";
import * as glob from "glob";

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

export function GetWorkingFolder(localpath, folder, logInfo): any {
    if (folder) {
        var targetPath = path.join(localpath, folder);
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

export function GetFileName(filename): any {
    var pathParts = path.parse(filename);
    return pathParts.base;
}

export function GetFolder(filename, sourceDir): any {
    var pathParts = path.parse(filename);
    return (path.relative(sourceDir, pathParts.dir));
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

export async function UpdateGitWikiFolder(
    protocol,
    repo,
    localpath,
    user,
    password,
    gitName,
    gitEmail,
    targetFolder,
    message,
    sourceFolder,
    filter,
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
    mode) {
    const git = simpleGit();

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
            await rimraf.rimrafSync(localpath);
        }
        logInfo(`Cleaned ${localpath}`);

        await git.clone(remote, localpath, extraHeaders);
        logInfo(`Cloned ${repo} to ${localpath}`);

        await git.cwd(localpath);
        logInfo(`Setting GitConfig Name:${gitName} Email:${gitEmail}`);
        await git.addConfig("user.name", gitName);
        await git.addConfig("user.email", gitEmail);
        logInfo(`Set GIT values in ${localpath}`);

        // move to the working folder
        process.chdir(localpath);

        if (branch) {
            logInfo(`Checking out the requested branch ${branch}`);
            await git.checkout(branch);
        }

        // do git pull just in case the clone was slow and there have been updates since
        // this is to try to reduce concurrency issues
        await git.pull();
        logInfo(`Git Pull, prior to local commits, in case of post clone updates to the repo from other users`);

        // make sure the slashes are in the correct format
        sourceFolder = sourceFolder.replace(/\\/g, "/");

        // get the list of file
        logInfo(`Checking for files using the filter ${sourceFolder}/${filter}`);
        var files = glob.sync(`${sourceFolder}/${filter}`);
        logInfo(`Found ${files.length} files`);

        for (let index = 0; index < files.length; index++) {
            logInfo(`Processing ${files[index]}`);
            var fileName = GetFileName(files[index]);
            var folder = GetFolder(files[index], sourceFolder);
            if (targetFolder) {
                folder = path.join(targetFolder, folder);
            }
            var workingPath = GetWorkingFolder(localpath, folder, logInfo);
            var targetFile = `${workingPath}/${fileName}`;
            if (replaceFile) {
                logInfo(`Copying the ${files[index]} to ${targetFile}`);
                fs.copyFileSync(files[index], targetFile);
            } else {
                var contents = fs.readFileSync(files[index], "utf8");
                if (appendToFile) {
                    fs.appendFileSync(targetFile, contents.replace(/`n/g, "\r\n"));
                    logInfo(`Appended to ${targetFile}`);
                } else {
                    var oldContent = "";
                    if (fs.existsSync(targetFile)) {
                        oldContent = fs.readFileSync(targetFile, "utf8");
                    }
                    fs.writeFileSync(targetFile, contents.replace(/`n/g, "\r\n"));
                    fs.appendFileSync(targetFile, oldContent);
                    logInfo(`Prepending to the ${targetFile}`);
                }
            }

            await git.add(targetFile);
            logInfo(`Added ${targetFile} to repo ${localpath}`);
        }

        var summary = await git.commit(message);
        if (summary.commit.length > 0) {
            logInfo(`Committed "${localpath}" with message "${message}" as SHA ${summary.commit}`);

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
            logInfo(`No commit was performed as no files have been added, deleted or edited`);
        }

    } catch (error) {
        logError(error);
    }
}

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}