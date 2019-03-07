import * as simplegit from "simple-git/promise";
import * as fs from "fs";
import * as rimraf from "rimraf";
import * as path from "path";

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
        logInfo(`Got the no directory passed change to ${localpath}`);
        return localpath;
    }
}

export async function UpdateGitWikiFile(repo, localpath, user, password, name, email, filename, message, contents, logInfo, logError) {
    const git = simplegit();

    let remote = "";
    if (password === null) {
        remote = `https://${repo}`;
    } else if (user === null) {
        remote = `https://${password}@${repo}`;
    } else {
        remote = `https://${user}:${password}@${repo}`;
    }
    logInfo(`URL used ${remote}`);

    try {
        if (fs.existsSync(localpath)) {
            await rimrafPromise(localpath);
        }
        logInfo(`Cleaned ${localpath}`);

        await git.silent(true).clone(remote, localpath);
        logInfo(`Cloned ${repo} to ${localpath}`);

        await git.cwd(localpath);
        await git.addConfig("user.name", name);
        await git.addConfig("user.email", email);
        logInfo(`Set GIT values in ${localpath}`);

        // move to the root folder
        process.chdir(GetWorkingFolder(localpath, filename, logInfo));

        // hander in case there is a folder

        // we need to change any encoded
        fs.writeFileSync(filename, contents.replace(/`n/g, "\r\n"));
        logInfo(`Created the ${filename} in ${localpath}`);

        await git.add(filename);
        logInfo(`Added ${filename} to repo ${localpath}`);

        await git.commit(message, filename);
        logInfo(`Committed to ${localpath}`);

        await git.push();
        logInfo(`Pushed to ${repo}`);
    } catch (error) {
        logError(error);
    }
}