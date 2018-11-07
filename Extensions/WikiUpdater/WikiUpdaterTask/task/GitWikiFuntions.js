"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const simplegit = require("simple-git/promise");
const fs = require("fs");
const rimraf = require("rimraf");
// A wrapper to make sure that directory delete is handled in sync
function rimrafPromise(localpath) {
    return new Promise((resolve, reject) => {
        rimraf(localpath, () => {
            resolve();
        }, (error) => {
            reject(error);
        });
    });
}
function UpdateGitWikiFile(repo, localpath, user, password, name, email, filename, message, contents, logInfo) {
    return __awaiter(this, void 0, void 0, function* () {
        const git = simplegit();
        const remote = `https://${user}:${password}@${repo}`;
        if (fs.existsSync(localpath)) {
            yield rimrafPromise(localpath);
        }
        logInfo(`Cleaned ${localpath}`);
        yield git.silent(true).clone(remote, localpath);
        logInfo(`Cloned ${repo} to ${localpath}`);
        yield git.cwd(localpath);
        yield git.addConfig("user.name", name);
        yield git.addConfig("user.email", email);
        logInfo(`Set GIT values in ${localpath}`);
        process.chdir(localpath);
        fs.writeFileSync(filename, contents);
        logInfo(`Created the ${filename} in ${localpath}`);
        yield git.add(filename);
        logInfo(`Added ${filename} to repo ${localpath}`);
        yield git.commit(message, filename);
        logInfo(`Committed to ${localpath}`);
        yield git.push();
        logInfo(`Pushed to ${repo}`);
    });
}
exports.UpdateGitWikiFile = UpdateGitWikiFile;
//# sourceMappingURL=GitWikiFuntions.js.map