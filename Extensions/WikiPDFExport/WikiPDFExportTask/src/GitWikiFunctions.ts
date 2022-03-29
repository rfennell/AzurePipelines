import simpleGit, { SimpleGit, CleanOptions } from "simple-git";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";
import * as process from "process";
import { logWarning } from "./agentSpecific";

// A wrapper to make sure that directory delete is handled in sync
function rimrafPromise (localpath)  {
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
        protocol = url.substr(0, url.indexOf("//") - 1 );
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

export async function CloneWikiRepo(
    protocol,
    repo,
    localpath,
    user,
    password,
    logInfo,
    logError,
    injectExtraHeader,
    branch) {
    const git = simpleGit();

    let remote = "";
    let logremote = ""; // used to make sure we hide the password in logs
    var extraHeaders = [];  // Add handling for #613

    if (injectExtraHeader) {
        remote = `${protocol}://${repo}`;
        logremote = remote;
        extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
        logInfo (`Injecting the authentication via the clone command using paramter -c http.extraheader='AUTHORIZATION: bearer ***'`);
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

        if (branch) {
            logInfo(`Checking out the requested branch ${branch}`);
            await git.checkout(branch);
        }

    } catch (error) {
        logError(error);
    }

}