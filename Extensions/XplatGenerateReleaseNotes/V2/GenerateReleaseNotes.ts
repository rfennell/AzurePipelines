import tl = require("vsts-task-lib/task");
import * as webApi from "vso-node-api/WebApi";
import { IReleaseApi } from "vso-node-api/ReleaseApi";
import * as vstsInterfaces from "vso-node-api/interfaces/common/VsoBaseInterfaces";

import { AgentSpecificApi } from "./agentSpecific";
import { Release } from "vso-node-api/interfaces/ReleaseInterfaces";
import * as util from "./ReleaseNotesFunctions";
import { IBuildApi } from "vso-node-api/BuildApi";
import { IWorkItemTrackingApi } from "vso-node-api/WorkItemTrackingApi";
import { Change } from "vso-node-api/interfaces/BuildInterfaces";
import { ResourceRef } from "vso-node-api/interfaces/common/VSSInterfaces";
import { WorkItemExpand, WorkItem, ArtifactUriQuery } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";
import * as issue349 from "./Issue349Workaround";

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
            let environmentName: string = (tl.getInput("overrideStageName") || tl.getVariable("Release_EnvironmentName")).toLowerCase();
            var templateLocation = tl.getInput("templateLocation", true);
            var templateFile = tl.getInput("templatefile");
            var inlineTemplate = tl.getInput("inlinetemplate");
            var outputfile = tl.getInput("outputfile", true);
            var outputVariableName = tl.getInput("outputVariableName");
            var emptyDataset = tl.getInput("emptySetText");
            var delimiter = tl.getInput("delimiter");
            if (delimiter === null) {
                agentApi.logInfo(`No delimiter passed, setting a default of :`);
                delimiter = ":";
            }

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
            let mostRecentSuccessfulDeploymentRelease: Release;

            agentApi.logInfo(`Getting all artifacts in the current release...`);
            var arifactsInThisRelease = util.getSimpleArtifactArray(currentRelease.artifacts);
            agentApi.logInfo(`Found ${arifactsInThisRelease.length}`);

            let arifactsInMostRecentRelease: util.SimpleArtifact[] = [];
            var mostRecentSuccessfulDeploymentName: string = "";
            if (mostRecentSuccessfulDeployment) {
                // Get the release that the deployment was a part of - This is required for the templating.
                mostRecentSuccessfulDeploymentRelease = await releaseApi.getRelease(teamProject, mostRecentSuccessfulDeployment.release.id);
                agentApi.logInfo(`Getting all artifacts in the most recent successful release [${mostRecentSuccessfulDeployment.release.name}]...`);
                arifactsInMostRecentRelease = util.getSimpleArtifactArray(mostRecentSuccessfulDeployment.release.artifacts);
                mostRecentSuccessfulDeploymentName = mostRecentSuccessfulDeployment.release.name;
                agentApi.logInfo(`Found ${arifactsInMostRecentRelease.length}`);
            } else {
                agentApi.logInfo(`Skipping fetching artifact in the most recent successful release as there isn't one.`);
                // we need to set the last successful as the current release to templates can get some data
                mostRecentSuccessfulDeploymentRelease = currentRelease;
            }

            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];

            for (var artifactInThisRelease of arifactsInThisRelease) {
                agentApi.logInfo(`Looking at artifact [${artifactInThisRelease.artifactAlias}]`);
                agentApi.logInfo(`Artifact type [${artifactInThisRelease.artifactType}]`);
                agentApi.logInfo(`Build Definition ID [${artifactInThisRelease.buildDefinitionId}]`);
                agentApi.logInfo(`Build Number: [${artifactInThisRelease.buildNumber}]`);

                if (arifactsInMostRecentRelease.length > 0) {
                    if (artifactInThisRelease.artifactType === "Build") {
                        agentApi.logInfo(`Looking for the [${artifactInThisRelease.artifactAlias}] in the most recent successful release [${mostRecentSuccessfulDeploymentName}]`);
                        for (var artifactInMostRecentRelease of arifactsInMostRecentRelease) {
                            if (artifactInThisRelease.artifactAlias.toLowerCase() === artifactInMostRecentRelease.artifactAlias.toLowerCase()) {
                                agentApi.logInfo(`Found artifact [${artifactInMostRecentRelease.artifactAlias}] with build number [${artifactInMostRecentRelease.buildNumber}] in release [${mostRecentSuccessfulDeploymentName}]`);

                                // Only get the commits and workitems if the builds are different
                                if (artifactInMostRecentRelease.buildNumber.toLowerCase() !== artifactInThisRelease.buildNumber.toLowerCase()) {
                                    agentApi.logInfo(`Checking what commits and workitems have changed from [${artifactInMostRecentRelease.buildNumber}] => [${artifactInThisRelease.buildNumber}]`);

                                    var commits: Change[];
                                    var workitems: ResourceRef[];

                                    // Check if workaround for issue #349 should be used
                                    let activateFix = tl.getVariable("ReleaseNotes.Fix349");
                                    if (activateFix && activateFix.toLowerCase() === "true") {
                                        agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                                        let baseBuild = await buildApi.getBuild(parseInt(artifactInMostRecentRelease.buildId));
                                        // There is only a workaround for Git but not for TFVC :(
                                        if (baseBuild.repository.type === "TfsGit") {
                                            let currentBuild = await buildApi.getBuild(parseInt(artifactInThisRelease.buildId));
                                            let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(vsts, baseBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
                                            commits = commitInfo.commits;
                                            workitems = commitInfo.workItems;
                                        } else {
                                            // Fall back to original behavior
                                            commits = await buildApi.getChangesBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                            workitems = await buildApi.getWorkItemsBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                        }
                                    } else {
                                        // Issue #349: These APIs are affected by the build API limitation and only return the latest 200 changes and work items associated to those changes
                                        commits = await buildApi.getChangesBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                        workitems = await buildApi.getWorkItemsBetweenBuilds(teamProject, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                    }

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
                    } else {
                        agentApi.logInfo(`Skipping artifact as cannot get WI and commits/changesets details`);
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
            var outputString = util.processTemplate(template, fullWorkItems, globalCommits, currentRelease, mostRecentSuccessfulDeploymentRelease, emptyDataset, delimiter);
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
