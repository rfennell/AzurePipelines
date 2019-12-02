import tl = require("vsts-task-lib/task");
import * as webApi from "vso-node-api/WebApi";
import { IReleaseApi } from "vso-node-api/ReleaseApi";
import * as vstsInterfaces from "vso-node-api/interfaces/common/VsoBaseInterfaces";

import { AgentSpecificApi } from "./agentSpecific";
import { Release } from "vso-node-api/interfaces/ReleaseInterfaces";
import * as util from "./ReleaseNotesFunctions";
import { IBuildApi } from "vso-node-api/BuildApi";
import { IWorkItemTrackingApi } from "vso-node-api/WorkItemTrackingApi";
import { Build, Change } from "vso-node-api/interfaces/BuildInterfaces";
import { ResourceRef } from "vso-node-api/interfaces/common/VSSInterfaces";
import { WorkItemExpand, WorkItem, ArtifactUriQuery } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";
import * as issue349 from "./Issue349Workaround";

let agentApi = new AgentSpecificApi();

async function run(): Promise<number>  {
    var promise = new Promise<number>(async (resolve, reject) => {

        try {
            agentApi.logDebug("Starting Tag XplatGenerateReleaseNotes task");

            let tpcUri = tl.getVariable("System.TeamFoundationCollectionUri");
            let teamProject = tl.getVariable("System.TeamProject");
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
            var stopOnRedeploy = tl.getBoolInput("stopOnRedeploy");
            var sortWi = tl.getBoolInput("SortWi");

            let credentialHandler: vstsInterfaces.IRequestHandler = util.getCredentialHandler();
            let vsts = new webApi.WebApi(tpcUri, credentialHandler);
            var releaseApi: IReleaseApi = await vsts.getReleaseApi();
            var buildApi: IBuildApi = await vsts.getBuildApi();

            // the result containers
            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];
            var mostRecentSuccessfulDeploymentName: string = "";
            let mostRecentSuccessfulDeploymentRelease: Release;

            var currentRelease: Release;
            var currentBuild: Build;

            if (tl.getVariable("Release.ReleaseId") === undefined) {
                agentApi.logInfo("Getting the current build details");
                let buildId: number = parseInt(tl.getVariable("Build.BuildId"));
                currentBuild = await buildApi.getBuild(buildId);

                if (!currentBuild) {
                    reject(`Unable to locate the current build with id ${buildId}`);
                    return;
                }

                globalCommits = await buildApi.getBuildChanges(teamProject, buildId);
                globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId);

            } else {
                let releaseId: number = parseInt(tl.getVariable("Release.ReleaseId"));
                let releaseDefinitionId: number = parseInt(tl.getVariable("Release.DefinitionId"));
                let environmentName: string = (tl.getInput("overrideStageName") || tl.getVariable("Release_EnvironmentName")).toLowerCase();

                agentApi.logInfo("Getting the current release details");
                currentRelease = await releaseApi.getRelease(teamProject, releaseId);

                // check of redeploy
                if (stopOnRedeploy === true) {
                    if ( util.getDeploymentCount(currentRelease.environments, environmentName) > 1) {
                        agentApi.logWarn(`Skipping release note generation as this deploy is a re-reployment`);
                        resolve(-1);
                        return promise;
                    }
                }

                if (!currentRelease) {
                    reject(`Unable to locate the current release with id ${releaseId}`);
                    return;
                }

                var environmentId = util.getReleaseDefinitionId(currentRelease.environments, environmentName);

                let mostRecentSuccessfulDeployment = await util.getMostRecentSuccessfulDeployment(releaseApi, teamProject, releaseDefinitionId, environmentId);
                let isInitialRelease = false;

                agentApi.logInfo(`Getting all artifacts in the current release...`);
                var arifactsInThisRelease = util.getSimpleArtifactArray(currentRelease.artifacts);
                agentApi.logInfo(`Found ${arifactsInThisRelease.length}`);

                let arifactsInMostRecentRelease: util.SimpleArtifact[] = [];
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
                    mostRecentSuccessfulDeploymentName = "Initial Deployment";
                    arifactsInMostRecentRelease = arifactsInThisRelease;
                    isInitialRelease = true;
                }

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

                                    var commits: Change[];
                                    var workitems: ResourceRef[];

                                    // Only get the commits and workitems if the builds are different
                                    if (isInitialRelease) {
                                        agentApi.logInfo(`This is the first release so checking what commits and workitems are associated with artifacts`);
                                        commits = await buildApi.getBuildChanges(teamProject, parseInt(artifactInThisRelease.buildId));
                                        workitems = await buildApi.getBuildWorkItemsRefs(teamProject, parseInt(artifactInThisRelease.buildId));
                                    } else if (artifactInMostRecentRelease.buildId !== artifactInThisRelease.buildId) {
                                        agentApi.logInfo(`Checking what commits and workitems have changed from [${artifactInMostRecentRelease.buildNumber}][ID ${artifactInMostRecentRelease.buildId}] => [${artifactInThisRelease.buildNumber}] [ID ${artifactInThisRelease.buildId}]`);

                                        // Check if workaround for issue #349 should be used
                                        let activateFix = tl.getVariable("ReleaseNotes.Fix349");
                                        if (!activateFix) {
                                            agentApi.logInfo("Defaulting on the workaround for build API limitation (see issue #349 set 'ReleaseNotes.Fix349=false' to disable)");
                                            activateFix = "true";
                                        }
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
                                    } else {
                                        agentApi.logInfo(`Build for artifact [${artifactInThisRelease.artifactAlias}] has not changed.  Nothing to do`);
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

                                }
                            }
                        } else {
                            agentApi.logInfo(`Skipping artifact as cannot get WI and commits/changesets details`);
                        }
                    }
                    agentApi.logInfo(``);
                }
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

            let fullWorkItems = [];
            agentApi.logInfo(`Get details of [${workItemIds.length}] WIs`);
            if (workItemIds.length > 0) {
                var indexStart = 0;
                var indexEnd = (workItemIds.length > 200) ? 200 : workItemIds.length ;
                while ((indexEnd <= workItemIds.length) && (indexStart !== indexEnd)) {
                    var subList = workItemIds.slice(indexStart, indexEnd);
                    agentApi.logInfo(`Getting full details of WI batch from index: [${indexStart}] to [${indexEnd}]`);
                    var subListDetails = await workItemTrackingApi.getWorkItems(subList, null, null, WorkItemExpand.Fields, null);
                    agentApi.logInfo(`Adding [${subListDetails.length}] items`);
                    fullWorkItems = fullWorkItems.concat(subListDetails);
                    indexStart = indexEnd;
                    indexEnd = ((workItemIds.length - indexEnd) > 200) ? indexEnd + 200 : workItemIds.length;
                }
            }

            agentApi.logInfo(`Total commits: [${globalCommits.length}]`);
            agentApi.logInfo(`Total workitems: [${fullWorkItems.length}]`);

            // by default order by ID, has the option to group by type
            if (sortWi) {
                agentApi.logInfo("Sorting WI by type then id");
                fullWorkItems = fullWorkItems.sort((a, b) => (a.fields["System.WorkItemType"] > b.fields["System.WorkItemType"]) ? 1 : (a.fields["System.WorkItemType"] === b.fields["System.WorkItemType"]) ? ((a.id > b.id) ? 1 : -1) : -1 );
            } else {
                agentApi.logInfo("Leaving WI in default order as returned by API");
            }

            var template = util.getTemplate (templateLocation, templateFile, inlineTemplate);
            var outputString = util.processTemplate(template, fullWorkItems, globalCommits, currentBuild, currentRelease, mostRecentSuccessfulDeploymentRelease, emptyDataset, delimiter);
            util.writeFile(outputfile, outputString);

            agentApi.writeVariable(outputVariableName, outputString.toString());

            resolve(0);
        } catch (err) {

            agentApi.logError(err);
            reject(err);
        }
    });
    return promise;
}

run()
    .then((result) => {
        if (result === -1) {
            tl.setResult(tl.TaskResult.SucceededWithIssues, "Skipped release notes generation as redeploy");
        } else {
            tl.setResult(tl.TaskResult.Succeeded, "");
        }
    })
    .catch((err) => {
        agentApi.publishEvent("reliability", { issueType: "error", errorMessage: JSON.stringify(err, Object.getOwnPropertyNames(err)) });
        tl.setResult(tl.TaskResult.Failed, err);
    });
