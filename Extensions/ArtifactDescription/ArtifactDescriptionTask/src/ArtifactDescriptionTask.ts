import * as vm from "azure-devops-node-api";
import * as lim from "azure-devops-node-api/interfaces/LocationsInterfaces";
import * as ba from "azure-devops-node-api/BuildApi";
import tl = require("vsts-task-lib/task");

import {
    logInfo,
    logError,
    getSystemAccessToken
}  from "./agentSpecific";
import { basename } from "path";

function getEnv(name: string): string {
    let val = process.env[name];
    if (!val) {
        logError(`${name} env var not set`);
        process.exit(1);
    }
    return val;
}

async function getWebApi(serverUrl?: string): Promise<vm.WebApi> {
    serverUrl = serverUrl || getEnv("System_TeamFoundationCollectionUri");
    return await this.getApi(serverUrl);
}

async function getApi(serverUrl: string): Promise<vm.WebApi> {
    return new Promise<vm.WebApi>(async (resolve, reject) => {
        try {
            let token = getEnv("API_TOKEN");
            let authHandler = vm.getPersonalAccessTokenHandler(token);
            let option = undefined;
            let vsts: vm.WebApi = new vm.WebApi(serverUrl, authHandler, option);
            let connData: lim.ConnectionData = await vsts.connect();
            logInfo(`Running as ${connData.authenticatedUser.providerDisplayName}`);
            resolve(vsts);
        }
        catch (err) {
            reject(err);
        }
    });
}

export async function run() {
    try {
        var outputText = tl.getInput("OutputText");
        let vsts: vm.WebApi = await getWebApi();
        let vstsBuild: ba.IBuildApi = await vsts.getBuildApi();
        let build = await vstsBuild.getBuild(getEnv("API_PROJECT"), parseInt(getEnv("BUILD_BUILDID")));
        logInfo(`Writing ${build.triggerInfo["pr.title"]} to variable ${outputText}`);
        tl.setVariable(outputText, build.triggerInfo["pr.title"] );
    }
    catch (err) {
        logError(err);
    }
}

run();
