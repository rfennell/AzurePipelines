import tl = require("azure-pipelines-task-lib/task");
import { IRequestHandler } from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import * as webApi from "azure-devops-node-api/WebApi";
import { IBuildApi } from "azure-devops-node-api/BuildApi";

import {
    logInfo,
    logError,
    getSystemAccessToken
}  from "./agentSpecific";
import { basename } from "path";

// Gets the credential handler.  Supports both PAT and OAuth tokens
function getCredentialHandler(): IRequestHandler {
    var accessToken: string = tl.getVariable("System.AccessToken");
    let credHandler: IRequestHandler;
    if (!accessToken || accessToken.length === 0) {
        throw "Unable to locate access token.  Please make sure you have enabled the \"Allow scripts to access OAuth token\" setting.";
    } else {
        tl.debug("Creating the credential handler");
        // used for local debugging.  Allows switching between PAT token and Bearer Token for debugging
        credHandler = webApi.getHandlerFromToken(accessToken);
    }
    return credHandler;
}

export async function run() {
    try {
        var outputText = tl.getInput("OutputText");
        let tpcUri = tl.getVariable("System.TeamFoundationCollectionUri");
        let project = tl.getVariable("System.TeamProject");
        let buildID = tl.getVariable("Build.BuildId");

        logInfo (`Output variable name: ${outputText}`);
        logInfo (`API URL: ${tpcUri}`);
        logInfo (`Project: ${project}`);
        logInfo (`Build ID: ${buildID}`);

        let credentialHandler: IRequestHandler = getCredentialHandler();
        let vsts = new webApi.WebApi(tpcUri, credentialHandler);
        var buildApi: IBuildApi = await vsts.getBuildApi();

        let build = await buildApi.getBuild( project , parseInt(buildID));
        logInfo(`Writing message '${build.triggerInfo["pr.title"]}' to variable '${outputText}'`);
        tl.setVariable(outputText, build.triggerInfo["pr.title"] );
    }
    catch (err) {
        logError(err);
    }
}

run();
