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
        // look for PR triggerInfo first we get this is the build is triggered as part of a PR
        if (build.triggerInfo["pr.title"]) {
            logInfo(`Writing message from the TriggerInfo - '${build.triggerInfo["pr.title"]}' to variable '${outputText}'`);
            tl.setVariable(outputText, build.triggerInfo["pr.title"] );
        } else {
            // if there is no triggerInfo it is probably a CI trigger off master or similar
            // Just try for the merge message
            let cs = await buildApi.getBuildChanges("GitHub" , parseInt(buildID));
            if (cs[0]) {
                logInfo(`Writing message from the first changeset - '${cs[0].message}' to variable '${outputText}'`);
                tl.setVariable(outputText, cs[0].message );
            }
        }
    }
    catch (err) {
        logError(err);
    }
}

run();
