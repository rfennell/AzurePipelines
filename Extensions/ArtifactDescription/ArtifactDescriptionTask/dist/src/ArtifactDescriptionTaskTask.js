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
const vm = require("azure-devops-node-api");
const tl = require("vsts-task-lib/task");
const agentSpecific_1 = require("./agentSpecific");
function getEnv(name) {
    let val = process.env[name];
    if (!val) {
        console.error(`${name} env var not set`);
        process.exit(1);
    }
    return val;
}
function getWebApi(serverUrl) {
    return __awaiter(this, void 0, void 0, function* () {
        serverUrl = serverUrl || getEnv("API_URL");
        return yield this.getApi(serverUrl);
    });
}
function getApi(serverUrl) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => __awaiter(this, void 0, void 0, function* () {
            try {
                let token = getEnv("API_TOKEN");
                let authHandler = vm.getPersonalAccessTokenHandler(token);
                let option = undefined;
                let vsts = new vm.WebApi(serverUrl, authHandler, option);
                let connData = yield vsts.connect();
                console.log(`Running as ${connData.authenticatedUser.providerDisplayName}`);
                resolve(vsts);
            }
            catch (err) {
                reject(err);
            }
        }));
    });
}
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            var outputText = tl.getInput("OutputText");
            let vsts = yield getWebApi();
            let vstsBuild = yield vsts.getBuildApi();
            let build = yield vstsBuild.getBuild(getEnv("API_PROJECT"), parseInt(getEnv("BUILD_BUILDID")));
            tl.setVariable(outputText, build.triggerInfo["pr.title"]);
        }
        catch (err) {
            agentSpecific_1.logError(err);
        }
    });
}
exports.run = run;
//# sourceMappingURL=ArtifactDescriptionTaskTask.js.map