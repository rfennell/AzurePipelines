import tl = require("azure-pipelines-task-lib/task");
import * as webApi from "azure-devops-node-api/WebApi";
import { IReleaseApi } from "azure-devops-node-api/ReleaseApi";
import * as vstsInterfaces from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";

import { AgentSpecificApi } from "./agentSpecific";
import { Release } from "azure-devops-node-api/interfaces/ReleaseInterfaces";
import * as util from "./ReleaseNotesFunctions";
import { IBuildApi } from "azure-devops-node-api/BuildApi";
import { IGitApi } from "azure-devops-node-api/GitApi";
import { IWorkItemTrackingApi } from "azure-devops-node-api/WorkItemTrackingApi";
import { Build, Change } from "azure-devops-node-api/interfaces/BuildInterfaces";
import { ResourceRef } from "azure-devops-node-api/interfaces/common/VSSInterfaces";
import { WorkItemExpand, WorkItem, ArtifactUriQuery } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";
import * as issue349 from "./Issue349Workaround";
import { GitPullRequest, GitPullRequestQueryType } from "azure-devops-node-api/interfaces/GitInterfaces";
import { all } from "q";

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
            var anyFieldContent = tl.getInput("anyFieldContent");
            var showOnlyPrimary = tl.getBoolInput("showOnlyPrimary");
            var searchCrossProjectForPRs = tl.getBoolInput("searchCrossProjectForPRs");
            if (delimiter === null) {
                agentApi.logInfo(`No delimiter passed, setting a default of :`);
                delimiter = ":";
            }
            var fieldEquality = tl.getInput("fieldEquality");
            if (fieldEquality === null) {
                agentApi.logInfo(`No fieldEquality passed, setting a default of =`);
                delimiter = "=";
            }

            if (fieldEquality === delimiter) {
                agentApi.logError (`The delimiter and field equality parameters cannot be the same, please change one. The usual defaults a : and = respectively`);
            }

            var stopOnRedeploy = tl.getBoolInput("stopOnRedeploy");
            var sortWi = tl.getBoolInput("SortWi");
            var customHandlebarsExtensionCode = tl.getInput("customHandlebarsExtensionCode");
            var customHandlebarsExtensionFile = tl.getInput("customHandlebarsExtensionFile");
            var customHandlebarsExtensionFolder = tl.getInput("customHandlebarsExtensionFolder");

            let credentialHandler: vstsInterfaces.IRequestHandler = util.getCredentialHandler();
            let vsts = new webApi.WebApi(tpcUri, credentialHandler);
            var releaseApi: IReleaseApi = await vsts.getReleaseApi();
            var buildApi: IBuildApi = await vsts.getBuildApi();
            var gitApi: IGitApi = await vsts.getGitApi();

            // the result containers
            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];
            var globalPullRequests: GitPullRequest[] = [];
            var globalBuilds: util.UnifiedArtifactDetails[] = [];

            var mostRecentSuccessfulDeploymentName: string = "";
            let mostRecentSuccessfulDeploymentRelease: Release;

            var currentRelease: Release;
            var currentBuild: Build;

            if (tl.getVariable("Release.ReleaseId") === undefined) {
                agentApi.logInfo("Getting the current build details");
                let buildId: number = parseInt(tl.getVariable("Build.BuildId"));
                currentBuild = await buildApi.getBuild(teamProject, buildId);

                if (!currentBuild) {
                    reject(`Unable to locate the current build with id ${buildId} in the project ${teamProject}`);
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

                agentApi.logInfo(`Show associated items for primary artifact only is set to ${showOnlyPrimary}`);

                // check of redeploy
                if (stopOnRedeploy === true) {
                    if ( util.getDeploymentCount(currentRelease.environments, environmentName) > 1) {
                        agentApi.logWarn(`Skipping release note generation as this deploy is a re-deployment`);
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
                    agentApi.logInfo(`Is Primary: [${artifactInThisRelease.isPrimary}]`);

                    if ((showOnlyPrimary === false) || (showOnlyPrimary === true && artifactInThisRelease.isPrimary === true)) {
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
                                            var builds = await buildApi.getBuilds(artifactInThisRelease.sourceId, [parseInt(artifactInThisRelease.buildDefinitionId)]);
                                            commits = [];
                                            workitems = [];

                                            for (var build of builds) {
                                                agentApi.logInfo(`Getting the details of ${build.id}`);
                                                var buildCommits = await buildApi.getBuildChanges(teamProject, build.id);
                                                commits.push(...buildCommits);
                                                var buildWorkitems = await buildApi.getBuildWorkItemsRefs(teamProject, build.id);
                                                workitems.push(...buildWorkitems);
                                            }
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
                                                let baseBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId));
                                                // There is only a workaround for Git but not for TFVC :(
                                                if (baseBuild.repository.type === "TfsGit") {
                                                    let currentBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInThisRelease.buildId));
                                                    let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(vsts, baseBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
                                                    commits = commitInfo.commits;
                                                    workitems = commitInfo.workItems;
                                                } else {
                                                    // Fall back to original behavior
                                                    commits = await buildApi.getChangesBetweenBuilds(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                                    workitems = await buildApi.getWorkItemsBetweenBuilds(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                                }
                                            } else {
                                                // Issue #349: These APIs are affected by the build API limitation and only return the latest 200 changes and work items associated to those changes
                                                commits = await buildApi.getChangesBetweenBuilds(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                                workitems = await buildApi.getWorkItemsBetweenBuilds(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId), 5000);
                                            }

                                        } else {
                                            agentApi.logInfo(`Build for artifact [${artifactInThisRelease.artifactAlias}] has not changed.  Nothing to do`);
                                        }

                                        // get artifact details for the unified output format
                                        let artifact = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId));
                                        globalBuilds.push(new util.UnifiedArtifactDetails(artifact, commits, workitems));

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
                    } else {
                        agentApi.logInfo(`Skipping artifact as only primary artifact required`);
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

            let expandedGlobalCommits = await util.expandTruncatedCommitMessages(vsts, globalCommits);

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

            agentApi.logInfo(`Total build artifacts: [${globalBuilds.length}]`);
            agentApi.logInfo(`Total commits: [${globalCommits.length}]`);
            agentApi.logInfo(`Total workitems: [${fullWorkItems.length}]`);

            // by default order by ID, has the option to group by type
            if (sortWi) {
                agentApi.logInfo("Sorting WI by type then id");
                fullWorkItems = fullWorkItems.sort((a, b) => (a.fields["System.WorkItemType"] > b.fields["System.WorkItemType"]) ? 1 : (a.fields["System.WorkItemType"] === b.fields["System.WorkItemType"]) ? ((a.id > b.id) ? 1 : -1) : -1 );
            } else {
                agentApi.logInfo("Leaving WI in default order as returned by API");
            }

            // to allow access to the PR details if any
            // this was the original PR enrichment behaviour
            // this only works for build triggered in PR validation

            // make sure we have an empty value if there is no PR
            // this is for backwards compat.
            var prDetails = <GitPullRequest> {};

            try {
                let buildId: number = parseInt(tl.getVariable("Build.BuildId"));
                if (isNaN(buildId)) {  // only try this if we have numeric build ID, not a GUID see #694
                    agentApi.logInfo(`Do not have an Azure DevOps numeric buildId, so skipping trying to get  any build PR trigger info`);
                } else {
                    agentApi.logDebug(`Getting the details of build ${buildId} from default project`);
                    currentBuild = await buildApi.getBuild(teamProject, buildId);
                    // and enhance the details if they can
                    if ((currentBuild.repository.type === "TfsGit") && (currentBuild.triggerInfo["pr.number"])) {
                        agentApi.logInfo(`The default artifact for the build/release was triggered by the PR ${currentBuild.triggerInfo["pr.number"]}, getting details`);
                        prDetails = await gitApi.getPullRequestById(parseInt(currentBuild.triggerInfo["pr.number"]));
                        globalPullRequests.push(prDetails);
                    } else {
                        agentApi.logInfo(`The default artifact for the release was not linked to an Azure DevOps Git Repo Pull Request`);
                    }
                }
            } catch (error) {
                agentApi.logWarn(`Could not get details of Trigger PR an error was seen: ${error}`);
            }

            // 2nd method aims to get the end of PR merges
            var prProjectFilter = "";
            if (searchCrossProjectForPRs) {
                agentApi.logInfo(`Getting all completed Azure DevOps Git Repo PRs in the Organisation`);
            } else {
                agentApi.logInfo(`Getting all completed Azure DevOps Git Repo PRs in the Team Project ${teamProject}`);
                prProjectFilter = teamProject;
            }

            var allPullRequests: GitPullRequest[] = await util.getPullRequests(gitApi, prProjectFilter);
            if (allPullRequests.length > 0) {
                agentApi.logInfo(`Found ${allPullRequests.length} Azure DevOps for PRs`);
                globalCommits.forEach(commit => {
                    if (commit.type === "TfsGit") {
                        agentApi.logInfo(`Checking for PRs associated with the commit ${commit.id}`);

                        allPullRequests.forEach(pr => {
                            if (pr.lastMergeCommit) {
                                if (pr.lastMergeCommit.commitId === commit.id) {
                                    agentApi.logInfo(`- PR ${pr.pullRequestId} matches the commit ${commit.id}`);
                                    globalPullRequests.push(pr);
                                }
                            } else {
                                console.log(`- PR ${pr.pullRequestId} does not have a lastMergeCommit`);
                            }
                        });

                    } else {
                        agentApi.logDebug(`Cannot check for associated PR as the commit ${commit.id} is not in an Azure DevOps repo`);
                    }
                });
            } else {
                agentApi.logDebug(`No completed Azure DevOps PRs found`);
            }

            // remove duplicates
            globalPullRequests = globalPullRequests.filter((thing, index, self) =>
                index === self.findIndex((t) => (
                t.pullRequestId === thing.pullRequestId
                ))
            );

            agentApi.logInfo(`Total Pull Requests: [${globalPullRequests.length}]`);

            var template = util.getTemplate (templateLocation, templateFile, inlineTemplate);
            var outputString = util.processTemplate(
                template,
                fullWorkItems,
                globalCommits,
                currentBuild,
                currentRelease,
                mostRecentSuccessfulDeploymentRelease,
                emptyDataset,
                delimiter,
                fieldEquality,
                anyFieldContent,
                customHandlebarsExtensionCode,
                prDetails,
                globalPullRequests,
                globalBuilds);

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
