import * as simplegit from "simple-git/promise";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";
import * as process from "process";
import { logWarning } from "./agentSpecific";
import { BranchSummary } from "simple-git/typings/response";

// A wrapper to make sure that directory delete is handled in sync
function rimrafPromise (localpath)  {
    return new Promise((resolve, reject) => {
        rimraf(localpath, () => {
            resolve();
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

export async function UpdateGitWikiFile(
    repo,
    localpath,
    user,
    password,
    name,
    email,
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
    branch) {
    const git = simplegit();

    let remote = "";
    let logremote = ""; // used to make sure we hide the password in logs
    var extraHeaders = [];  // Add handling for #613

    if (injectExtraHeader) {
        remote = `https://${repo}`;
        logremote = remote;
        extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
        logInfo (`Injecting the authentication via the clone command using paramter -c http.extraheader='AUTHORIZATION: bearer ***'`);
    } else {
        if (password === null) {
            remote = `https://${repo}`;
            logremote = remote;
        } else if (user === null) {
            remote = `https://${password}@${repo}`;
            logremote = `https://***@${repo}`;
        } else {
            remote = `https://${user}:${password}@${repo}`;
            logremote = `https://${user}:***@${repo}`;
        }
    }

    logInfo(`URL used ${logremote}`);

    try {
        if (fs.existsSync(localpath)) {
            await rimrafPromise(localpath);
        }
        logInfo(`Cleaned ${localpath}`);

        await git.silent(true).clone(remote, localpath, extraHeaders);
        logInfo(`Cloned ${repo} to ${localpath}`);

        await git.cwd(localpath);
        await git.addConfig("user.name", name);
        await git.addConfig("user.email", email);
        logInfo(`Set GIT values in ${localpath}`);

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
        logInfo(`Pull in case of post clone updates from other users`);

        // we need to change any encoded
        var workingFile = GetWorkingFile(filename, logInfo);
        if (replaceFile) {
            fs.writeFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
            logInfo(`Created the ${workingFile} in ${workingPath}`);
        } else {
            if (appendToFile) {
                fs.appendFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
                logInfo(`Appended to the ${workingFile} in ${workingPath}`);
            } else {
                var oldContent = "";
                if (fs.existsSync(workingFile)) {
                    oldContent = fs.readFileSync(workingFile, "utf8");
                }
                fs.writeFileSync(workingFile, contents.replace(/`n/g, "\r\n"));
                fs.appendFileSync(workingFile, oldContent);
                logInfo(`Prepending to the ${workingFile} in ${workingPath}`);
            }
        }

        await git.add(filename);
        logInfo(`Added ${filename} to repo ${localpath}`);

        var summary = await git.commit(message);
        if (summary.commit.length > 0) {
            logInfo(`Committed file "${localpath}" with message "${message}" as SHA ${summary.commit}`);
            logInfo(summary.summary);
            
            await git.push();
            logInfo(`Pushed to ${repo}`);

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