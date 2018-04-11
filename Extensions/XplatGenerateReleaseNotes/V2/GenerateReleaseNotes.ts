import tl = require("vsts-task-lib/task");
import * as webApi from "vso-node-api/WebApi";
import { IReleaseApi } from "vso-node-api/ReleaseApi";
import * as vstsInterfaces from "vso-node-api/interfaces/common/VsoBaseInterfaces";

import { IAgentSpecificApi, AgentSpecificApi } from "./agentSpecific";
import { ReleaseEnvironment, DeploymentStatus, Deployment } from "vso-node-api/interfaces/ReleaseInterfaces";
import * as util from "./ReleaseNotesFunctions";
import { release } from "os";
import { IBuildApi } from "vso-node-api/BuildApi";
import { IWorkItemTrackingApi } from "vso-node-api/WorkItemTrackingApi";
import { Change } from "vso-node-api/interfaces/BuildInterfaces";
import { ResourceRef } from "vso-node-api/interfaces/common/VSSInterfaces";
import { IGitApi } from "vso-node-api/GitApi";
import { WorkItemExpand, WorkItem } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";

let agentApi = new AgentSpecificApi();

async function run(): Promise<void>  {
    var promise = new Promise<void>(async (resolve, reject) => {

        try {
            agentApi.logDebug("Starting Tag XplatGenerateReleaseNotes task");

            let tpcUri = tl.getVariable("System.TeamFoundationCollectionUri");
            let teamProject = tl.getVariable("System.TeamProject");
            let releaseId: number = parseInt(tl.getVariable("Release.ReleaseId"));
            let releaseDefinitionId: number = parseInt(tl.getVariable("Release.DefinitionId"));

            // Inputs
            let environmentName: string = (tl.getInput("overrideStage") || tl.getVariable("Release_EnvironmentName")).toLowerCase();
            var templateLocation = tl.getInput("templateLocation", true);
            var templateFile = tl.getInput("templatefile");
            var inlineTemplate = tl.getInput("inlinetemplate");
            var outputfile = tl.getInput("outputfile", true);
            var outputVariableName = tl.getInput("outputVariableName");
            var emptyDataset = tl.getInput("emptySetText");

            let credentialHandler: vstsInterfaces.IRequestHandler = util.getCredentialHandler();
            let vsts = new webApi.WebApi(tpcUri, credentialHandler);
            var releaseApi: IReleaseApi = await vsts.getReleaseApi();
            var buildApi: IBuildApi = await vsts.getBuildApi();

            agentApi.logInfo("Getting the current release details");
            var currentRelease = await releaseApi.getRelease(teamProject, releaseId);

            if (!currentRelease) {
                reject(`Unable to locate the current release with id ${releaseId}`);
                return;
            }

            var environmentId = util.getReleaseDefinitionId(currentRelease.environments, environmentName);

            let mostRecentSuccessfulDeployment = await util.getMostRecentSuccessfulDeployment(releaseApi, teamProject, releaseDefinitionId, environmentId);

            agentApi.logInfo(`Getting all artifacts in the current release...`);
            var arifactsInThisRelease = util.getSimpleArtifactArray(currentRelease.artifacts);
            agentApi.logInfo(`Found ${arifactsInThisRelease.length}`);

            let arifactsInMostRecentRelease: util.SimpleArtifact[] = [];
            var mostRecentSuccessfulDeploymentName: string = "";
            if (mostRecentSuccessfulDeployment) {
                agentApi.logInfo(`Getting all artifacts in the most recent successful release [${mostRecentSuccessfulDeployment.release.name}]...`);
                arifactsInMostRecentRelease = util.getSimpleArtifactArray(mostRecentSuccessfulDeployment.release.artifacts);
                mostRecentSuccessfulDeploymentName = mostRecentSuccessfulDeployment.release.name;
                agentApi.logInfo(`Found ${arifactsInMostRecentRelease.length}`);
            } else {
                agentApi.logInfo(`Skipping fetching artifact in the most recent successful release as there isn't one.`);
            }

            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];

            for (var artifactInThisRelease of arifactsInThisRelease) {
                agentApi.logInfo(`Looking at artifact [${artifactInThisRelease.artifactAlias}]`);
                agentApi.logInfo(`Build Number: [${artifactInThisRelease.buildNumber}]`);

                var buildNumberFromMostRecentBuild = null;

                if (arifactsInMostRecentRelease.length > 0) {
                    agentApi.logInfo(`Looking for the [${artifactInThisRelease.artifactAlias}] in the most recent successful release [${mostRecentSuccessfulDeploymentName}]`);
                    for (var artifactInMostRecentRelease of arifactsInMostRecentRelease) {
                        if (artifactInThisRelease.artifactAlias.toLowerCase() === artifactInMostRecentRelease.artifactAlias.toLowerCase()) {
                            agentApi.logInfo(`Found artifact [${artifactInThisRelease.artifactAlias}] with build number [${artifactInThisRelease.buildNumber}] in release [${mostRecentSuccessfulDeploymentName}]`);

                            // Only get the commits and workitems if the builds are different
                            if (artifactInMostRecentRelease.buildNumber.toLowerCase() !== artifactInThisRelease.buildNumber.toLowerCase()) {
                                agentApi.logInfo(`Checking what commits and workitems have changed from [${artifactInMostRecentRelease.buildNumber}] => [${artifactInThisRelease.buildNumber}]`);

                                var commits = await buildApi.getChangesBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);

                                var workitems = await buildApi.getWorkItemsBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);

                                var commitCount: number = 0;
                                var workItemCount: number = 0;

                                if (commits) {
                                    commitCount = commits.length;
                                    globalCommits = globalCommits.concat(commits);
                                }

                                if (workitems) {
                                    workItemCount = workitems.length;
                                    globalWorkItems = globalWorkItems.concat(workitems);
                                }

                                agentApi.logInfo(`Detected ${commitCount} commits/changesets and ${workItemCount} workitems between the builds.`);
                            } else {
                                agentApi.logInfo(`Build for artifact [${artifactInThisRelease.artifactAlias}] has not changed.  Nothing to do`);
                            }
                        }
                    }
                }
                agentApi.logInfo(``);
            }

            // remove duplicates
            globalCommits = globalCommits.filter((thing, index, self) =>
                index === self.findIndex((t) => (
                t.id === thing.id
                ))
            );

            globalWorkItems = globalWorkItems.filter((thing, index, self) =>
                index === self.findIndex((t) => (
                t.id === thing.id
                ))
            );

            let expandedGlobalCommits = await util.expandTruncatedCommitMessages(vsts.rest, globalCommits);

            if (!expandedGlobalCommits || expandedGlobalCommits.length !== globalCommits.length) {
                reject("Failed to expand the global commits.");
                return;
            }

            // get an array of workitem ids
            var workItemIds = globalWorkItems.map(wi => parseInt(wi.id));
            var workItemTrackingApi: IWorkItemTrackingApi = await vsts.getWorkItemTrackingApi();

            let fullWorkItems: void | WorkItem[];
            if (workItemIds.length > 0) {
                fullWorkItems = await workItemTrackingApi.getWorkItems(workItemIds, null, null, WorkItemExpand.Fields, null);
            }

            if (!fullWorkItems) {
                fullWorkItems = [];
            }

            agentApi.logInfo(`Total commits: [${globalCommits.length}]`);
            agentApi.logInfo(`Total workitems: [${globalWorkItems.length}]`);

            var template = util.getTemplate (templateLocation, templateFile, inlineTemplate);
            var outputString = util.processTemplate(template, fullWorkItems, globalCommits, currentRelease, emptyDataset);
            util.writeFile(outputfile, outputString);

            agentApi.writeVariable(outputVariableName, outputString.toString());

            resolve();
        } catch (err) {

            agentApi.logError(err);
            reject(err);
        }
    });
    return promise;
}

run()
    .then((result) => {
        tl.setResult(tl.TaskResult.Succeeded, "");
    })
    .catch((err) => {
        agentApi.publishEvent("reliability", { issueType: "error", errorMessage: JSON.stringify(err, Object.getOwnPropertyNames(err)) });
        tl.setResult(tl.TaskResult.Failed, err);
    });