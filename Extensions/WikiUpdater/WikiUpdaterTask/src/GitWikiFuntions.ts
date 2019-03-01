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

export async function SetWorkingFolder(localpath, filename, logInfo) {
    var pathParts = path.parse(filename);
    if (pathParts.dir && pathParts.dir !== "/" && pathParts.dir !== "\\") {
        logInfo(`Got the directory ${pathParts.dir}`);
        logInfo(fs.existsSync(path.join(localpath, path.join(pathParts.dir))));
    } else {
        logInfo(`Got the no directory passed change to ${localpath}`);
        process.chdir(localpath);
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
        process.chdir(localpath);

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