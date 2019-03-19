import * as webApi from "vso-node-api/WebApi";
import { IReleaseApi } from "vso-node-api/ReleaseApi";
import * as vstsInterfaces from "vso-node-api/interfaces/common/VsoBaseInterfaces";

async function run(): Promise<void>  {
    console.log ("Start Export");

    var tpcUri = "https://dev.azure.com/richardfennell/";
    // assuming I am autneticated I don't need to provide a PAT
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