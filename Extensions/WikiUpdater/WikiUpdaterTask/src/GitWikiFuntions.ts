import * as simplegit from "simple-git/promise";
import * as fs from "fs";
import * as rimraf from "rimraf";

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

export async function UpdateGitWikiFile(repo, localpath, user, password, name, email, filename, message, contents, logInfo) {
    const git = simplegit();

    const remote = `https://${user}:${password}@${repo}`;

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

    process.chdir(localpath);
    fs.writeFileSync(filename, contents);
    logInfo(`Created the ${filename} in ${localpath}`);

    await git.add(filename);
    logInfo(`Added ${filename} to repo ${localpath}`);

    await git.commit(message, filename);
    logInfo(`Committed to ${localpath}`);

    await git.push();
    logInfo(`Pushed to ${repo}`);
}