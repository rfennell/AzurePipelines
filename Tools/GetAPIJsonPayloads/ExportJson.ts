import * as webApi from "azure-devops-node-api/WebApi";
import { IReleaseApi } from "azure-devops-node-api/ReleaseApi";

async function run(): Promise<void>  {
    console.log ("Start Export");

    var tpcUri = "https://dev.azure.com/richardfennell/";
    // assuming I am authenticated I don't need to provide a PAT
    var pat = "";
    var teamProject = "GitHub";
    var releaseId = 1285;
    let credHandler = webApi.getHandlerFromToken(pat);
    let vsts = new webApi.WebApi(tpcUri, credHandler);
    var releaseApi: IReleaseApi = await vsts.getReleaseApi();
    var release = await releaseApi.getRelease(teamProject, releaseId);
    console.log (release);

    console.log ("End Export");
}

run();