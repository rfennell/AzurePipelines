import * as simplegit from "simple-git/promise";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";
import * as process from "process";
import { logWarning } from "./agentSpecific";
import { BranchSummary } from "simple-git/typings/response";
import * as glob from "glob";

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

export async function UpdateGitWikiFile(
    repo,
    localpath,
    user,
    password,
    name,
    email,
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
        process.chdir(localpath);

        if (branch) {
            logInfo(`Checking out the requested branch ${branch}`);
            await git.checkout(branch);
        }

        // do git pull just in case the clone was slow and there have been updates since
        // this is to try to reduce concurrency issues
        await git.pull();
        logInfo(`Pull in case of post clone updates from other users`);

        // get the list of file
        logInfo(`Checking for files using the filter ${sourceFolder}/${filter}`);
        var files = glob.sync(`${sourceFolder}/${filter}`);
        logInfo(`Found ${files.length} files`);

        for (let index = 0; index < files.length; index++) {
            logInfo(`Processing ${files[index]}`);
            var fileName = GetFileName(files[index]);
            var folder = GetFolder(files[index], sourceFolder);
            if (targetFolder) {
                folder =  path.join(targetFolder, folder);
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

        await git.commit(message);
        logInfo(`Committed to ${localpath} with message "${message}`);

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

    } catch (error) {
        logError(error);
    }
}