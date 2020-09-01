export interface SimpleArtifact {
    artifactAlias: string;
    buildDefinitionId: string;
    buildNumber: string;
    buildId: string;
    artifactType: string;
    isPrimary: boolean;
    sourceId: string;
}

export class UnifiedArtifactDetails {
    build: Build;
    commits: Change[];
    workitems: WorkItem[];
    tests: TestCaseResult[];
    constructor ( build: Build, commits: Change[], workitems: WorkItem[], tests: TestCaseResult[]) {
        this.build = build;
        if (commits) {
            this.commits = commits;
        } else {
            this.commits = [];
        }
        if (workitems) {
            this.workitems = workitems;
        } else {
            this.workitems = [];
        }
        if (tests) {
            this.tests = tests;
        } else {
            this.tests = [];
        }
   }
}

import * as restm from "typed-rest-client/RestClient";
import { PersonalAccessTokenCredentialHandler, BasicCredentialHandler } from "typed-rest-client/Handlers";
import tl = require("azure-pipelines-task-lib/task");
import { ReleaseEnvironment, Artifact, Deployment, DeploymentStatus, Release } from "azure-devops-node-api/interfaces/ReleaseInterfaces";
import { IAgentSpecificApi, AgentSpecificApi } from "./agentSpecific";
import { IReleaseApi } from "azure-devops-node-api/ReleaseApi";
import { IRequestHandler } from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import * as webApi from "azure-devops-node-api/WebApi";
import fs  = require("fs");
import { Build, Change, Timeline, TimelineRecord } from "azure-devops-node-api/interfaces/BuildInterfaces";
import { IGitApi, GitApi } from "azure-devops-node-api/GitApi";
import { ResourceRef } from "azure-devops-node-api/interfaces/common/VSSInterfaces";
import { GitCommit, GitPullRequest, GitPullRequestQueryType, GitPullRequestSearchCriteria, PullRequestStatus } from "azure-devops-node-api/interfaces/GitInterfaces";
import { WebApi } from "azure-devops-node-api";
import { TestApi } from "azure-devops-node-api/TestApi";
import { timeout, async } from "q";
import { TestCaseResult } from "azure-devops-node-api/interfaces/TestInterfaces";
import { IWorkItemTrackingApi } from "azure-devops-node-api/WorkItemTrackingApi";
import { WorkItemExpand, WorkItem, ArtifactUriQuery } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";
import { ITfvcApi } from "azure-devops-node-api/TfvcApi";
import * as issue349 from "./Issue349Workaround";
import { ITestApi } from "azure-devops-node-api/TestApi";
import { IBuildApi, BuildApi } from "azure-devops-node-api/BuildApi";
import * as vstsInterfaces from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import { time } from "console";

let agentApi = new AgentSpecificApi();

export function getDeploymentCount(environments: ReleaseEnvironment[], environmentName: string): number {
    agentApi.logInfo(`Getting deployment count for stage`);
    var attemptCount = 0;
    for (let environment of environments) {
        if (environment.name.toLowerCase() === environmentName) {
            var currentDeployment = environment.preDeployApprovals[environment.preDeployApprovals.length - 1];
            attemptCount = currentDeployment.attempt;
        }
    }
    if (attemptCount === 0) {
        throw `Failed to locate stage with name ${environmentName} so cannot get attempt`;
    }
    agentApi.logInfo(`Identified [${environmentName}] as having deployment count of [${attemptCount}]`);
    return attemptCount;
}

export function getReleaseDefinitionId(environments: ReleaseEnvironment[], environmentName: string): number {
    agentApi.logInfo(`Getting the Environment Id`);
    var environmentId: number = 0;
    for (let environment of environments) {
        if (environment.name.toLowerCase() === environmentName) {
            environmentId = environment.definitionEnvironmentId;
        }
    }
    if (environmentId === 0) {
        throw `Failed to locate environment with name ${environmentName}`;
    }
    agentApi.logInfo(`Identified [${environmentName}] as having id [${environmentId}]`);
    return environmentId;
}

export function getSimpleArtifactArray(artifacts: Artifact[]): SimpleArtifact[] {
    var result: SimpleArtifact[] = [];
    for (let artifact of artifacts) {
        result.push(
            {
                "artifactAlias": artifact.alias,
                "buildDefinitionId": artifact.definitionReference.definition.id,
                "buildNumber": artifact.definitionReference.version.name,
                "buildId": artifact.definitionReference.version.id,
                "artifactType": artifact.type,
                "isPrimary": artifact.isPrimary,
                "sourceId": artifact.sourceId.split(":")[0]
            }
        );
    }
    return result;
}

export async function getPullRequests(gitApi: GitApi, projectName: string): Promise<GitPullRequest[]> {
    return new Promise<GitPullRequest[]>(async (resolve, reject) => {
        let prList: GitPullRequest[];
        try {
            var filter: GitPullRequestSearchCriteria = {
                creatorId: "",
                includeLinks: true,
                repositoryId: "",
                reviewerId: "",
                sourceRefName: "",
                sourceRepositoryId: "",
                status: PullRequestStatus.Completed,
                targetRefName: ""
            };
            prList = await gitApi.getPullRequestsByProject( projectName, filter);
            resolve(prList);
        } catch (err) {
            reject(err);
        }
    });
}

export async function getMostRecentSuccessfulDeployment(releaseApi: IReleaseApi, teamProject: string, releaseDefinitionId: number, environmentId: number): Promise<Deployment> {
    return new Promise<Deployment>(async (resolve, reject) => {

        let mostRecentDeployment: Deployment = null;
        try {
            // Gets the latest successful deployments - the api returns the deployments in the correct order
            var successfulDeployments = await releaseApi.getDeployments(teamProject, releaseDefinitionId, environmentId, null, null, null, DeploymentStatus.Succeeded, null, true, null, null, null, null).catch((reason) => {
                reject(reason);
                return;
            });

            if (successfulDeployments && successfulDeployments.length > 0) {
                mostRecentDeployment = successfulDeployments[0];
            } else {
                // There have been no recent successful deployments
            }
            resolve(mostRecentDeployment);
        } catch (err) {
            reject(err);
        }
    });
}

export async function expandTruncatedCommitMessages(restClient: WebApi, globalCommits: Change[], gitHubPat: string, bitbucketUser: string, bitbucketSecret: string): Promise<Change[]> {
    return new Promise<Change[]>(async (resolve, reject) => {
            var expanded: number = 0;
            agentApi.logInfo(`Expanding the truncated commit messages...`);
            for (var change of globalCommits) {
                if (change.messageTruncated) {
                    try {
                        agentApi.logDebug(`Expanding commit [${change.id}]`);
                        let res: restm.IRestResponse<GitCommit>;
                        if (change.location.startsWith("https://api.github.com/")) {
                            agentApi.logDebug(`Need to expand details from GitHub`);
                            // we build PAT auth object even if we have no token
                            // this will still allow access to public repos
                            // if we have a token it will allow access to private ones
                            let auth = new PersonalAccessTokenCredentialHandler(gitHubPat);

                            let rc = new restm.RestClient("rest-client", "", [auth], {});
                            let gitHubRes: any = await rc.get(change.location); // we have to use type any as  there is a type mismatch
                            if (gitHubRes.statusCode === 200) {
                                change.message = gitHubRes.result.commit.message;
                                change.messageTruncated = false;
                                expanded++;
                            } else {
                                agentApi.logWarn(`Cannot access API ${gitHubRes.statusCode} accessing ${change.location}`);
                                agentApi.logWarn(`The most common reason for this failure is that the GitHub Repo is private and a Personal Access Token giving read access needs to be passed as a parameter to this task`);
                            }
                        } else if (change.location.startsWith("https://api.bitbucket.org/")) {
                                agentApi.logDebug(`Need to expand details from BitBucket`);
                                // we build PAT auth object even if we have no token
                                // this will still allow access to public repos
                                // if we have a token it will allow access to private ones
                                let rc = new restm.RestClient("rest-client");
                                if (bitbucketUser && bitbucketUser.length > 0 && bitbucketSecret && bitbucketSecret.length > 0 ) {
                                    let auth = new BasicCredentialHandler(bitbucketUser, bitbucketSecret);
                                    rc = new restm.RestClient("rest-client", "", [auth], {});
                                } else {
                                    agentApi.logInfo(`No Bitbucket user and app secret passed so cannot access private Bitbucket repos`);
                                }

                                let bitbucketRes: any = await rc.get(change.location); // we have to use type any as  there is a type mismatch
                                if (bitbucketRes.statusCode === 200) {
                                    change.message = bitbucketRes.result.message;
                                    change.messageTruncated = false;
                                    expanded++;
                                } else {
                                    agentApi.logWarn(`Cannot access API ${bitbucketRes.statusCode} accessing ${change.location}`);
                                    agentApi.logWarn(`The most common reason for this failure is that the Bitbucket Repo is private and a Personal Access Token giving read access needs to be passed as a parameter to this task`);
                                }
                        } else {
                            agentApi.logDebug(`Need to expand details from Azure DevOps`);
                            // the REST client is already authorised with the agent token
                            let vstsRes = await restClient.rest.get<GitCommit>(change.location);
                            if (vstsRes.statusCode === 200) {
                                change.message = vstsRes.result.comment;
                                change.messageTruncated = false;
                                expanded++;
                            } else {
                                agentApi.logWarn(`Cannot access API ${vstsRes.statusCode} accessing ${change.location}`);
                                agentApi.logWarn(`The most common reason for this failure is that the account defined by the agent access token does not  have rights to read the required repo`);
                            }
                        }
                    } catch (err) {
                        agentApi.logWarn(`Cannot expand message ${err}`);
                        agentApi.logWarn(`Using ${change.location}`);
                    }
                }
            }
            agentApi.logWarn(`Expanded ${expanded}`);
            resolve(globalCommits);
    });
}

export async function enrichChangesWithFileDetails(
    gitApi: IGitApi,
    tfvcApi: ITfvcApi,
    changes: Change[],
    gitHubPat: string
): Promise<Change[]> {
    return new Promise<Change[]>(async (resolve, reject) => {
        try {
            var extraDetail = [];
            for (let index = 0; index < changes.length; index++) {
                const change = changes[index];
                try {
                    agentApi.logInfo (`Enriched change ${change.id} of type ${change.type}`);
                    if (change.type === "TfsGit") {
                        // we need the repository ID for the API call
                        // the alternative is to take the basic location value and build a rest call form that
                        // neither are that nice.
                        var url = require("url");
                        // split the url up, check it is the expected format and then get the ID
                        var urlParts = url.parse(change.location);
                        if (urlParts.host === "dev.azure.com") {
                            var pathParts = urlParts.path.split("/");
                            var repoId = "";
                            for (let index = 0; index < pathParts.length; index++) {
                                if (pathParts[index] === "repositories") {
                                    repoId = pathParts[index + 1];
                                    break;
                                }
                            }
                            let gitDetails = await gitApi.getChanges(change.id, repoId);
                            agentApi.logInfo (`Enriched with details of ${gitDetails.changes.length} files`);
                            extraDetail = gitDetails.changes;
                        } else  {
                            agentApi.logInfo (`Cannot enriched as location URL not in dev.azure.com format`);
                        }
                    } else if (change.type === "TfsVersionControl") {
                        var tfvcDetail = await tfvcApi.getChangesetChanges(parseInt(change.id.substring(1)));
                        agentApi.logInfo (`Enriched with details of ${tfvcDetail.length} files`);
                        extraDetail = tfvcDetail;
                    } else if (change.type === "GitHub") {
                        let res: restm.IRestResponse<GitCommit>;
                        // we build PAT auth object even if we have no token
                        // this will still allow access to public repos
                        // if we have a token it will allow access to private ones
                        let auth = new PersonalAccessTokenCredentialHandler(gitHubPat);
                        let rc = new restm.RestClient("rest-client", "", [auth], {});
                        let gitHubRes: any = await rc.get(change.location); // we have to use type any as  there is a type mismatch
                        if (gitHubRes.statusCode === 200) {
                            var gitHubFiles = gitHubRes.result.files;
                            agentApi.logInfo (`Enriched with details of ${gitHubFiles.length} files`);
                            extraDetail = gitHubFiles;
                        } else {
                            agentApi.logWarn(`Cannot access API ${gitHubRes.statusCode} accessing ${change.location}`);
                            agentApi.logWarn(`The most common reason for this failure is that the GitHub Repo is private and a Personal Access Token giving read access needs to be passed as a parameter to this task`);
                        }
                    } else if (change.type === "Bitbucket") {
                            agentApi.logWarn(`This task does not currently support getting file details associated to a commit on Bitbucket`);
                    } else {
                        agentApi.logWarn(`Cannot preform enrichment as type ${change.type} is not supported for enrichment`);
                    }
                    change["changes"] = extraDetail;
                } catch (err) {
                    agentApi.logWarn(`Error ${err} enriching ${change.location}`);
                }
            }
            resolve(changes);
        } catch (err) {
            reject(err);
        }
    });
}

// Gets the credential handler.  Supports both PAT and OAuth tokens
export function getCredentialHandler(pat: string): IRequestHandler {
    if (!pat || pat.length === 0) {
        // no pat passed so we need the system token
        tl.debug("Getting System.AccessToken");
        var accessToken = agentApi.getSystemAccessToken();
        let credHandler: IRequestHandler;
        if (!accessToken || accessToken.length === 0) {
            throw "Unable to locate access token that will allow access to Azure DevOps API.";
        } else {
            tl.debug("Creating the credential handler");
            // used for local debugging.  Allows switching between PAT token and Bearer Token for debugging
            credHandler = webApi.getHandlerFromToken(accessToken);
        }
        return credHandler;
    } else {
        tl.debug("Using PAT (suitable for local test only)");
        return webApi.getPersonalAccessTokenHandler(pat);
    }

}

export async function getTestsForBuild(
    testAPI: TestApi,
    teamProject: string,
    buildId: number
): Promise<TestCaseResult[]> {
    return new Promise<TestCaseResult[]>(async (resolve, reject) => {
        let testList: TestCaseResult[] = [];
        try {
            let builtTestResults = await testAPI.getTestResultsByBuild(teamProject, buildId);
            if ( builtTestResults.length > 0 ) {
                for (let index = 0; index < builtTestResults.length; index++) {
                    const test = builtTestResults[index];
                    if (testList.filter(e => e.testRun.id === `${test.runId}`).length === 0) {
                        tl.debug(`Adding tests for test run ${test.runId}`);
                        let run = await testAPI.getTestResults(teamProject, test.runId);
                        testList.push(...run);
                    } else {
                        tl.debug(`Skipping adding tests for test run ${test.runId} as already added`);
                    }
                }
            } else {
                tl.debug(`No tests associated with build ${buildId}`);
            }
            resolve(testList);
        } catch (err) {
            reject(err);
        }
    });
}

export function addUniqueTestToArray (
    masterArray: TestCaseResult[],
    newArray: TestCaseResult[]
) {
    tl.debug(`The global test array contains ${masterArray.length} items`);
    if (newArray.length > 0) {
        newArray.forEach(test => {
            if (masterArray.filter(e => e.testCaseReferenceId === test.testCaseReferenceId && e.testRun.id === test.testRun.id).length === 0) {
                tl.debug(`Adding the test case ${test.testCaseReferenceId} for test run ${test.testRun.id} as not present in the master list`);
                masterArray.push(test);
            } else {
                tl.debug(`Skipping the test case ${test.testCaseReferenceId} for test run ${test.testRun.id} as already present in the master list`);
            }
        });
    }
    tl.debug(`The updated global test array contains ${masterArray.length} items`);
    return masterArray;
}

export async function getTestsForRelease(
    testAPI: TestApi,
    teamProject: string,
    release: Release
): Promise<TestCaseResult[]> {
    return new Promise<TestCaseResult[]>(async (resolve, reject) => {
        let testList: TestCaseResult[] = [];
        try {
            for (let envIndex = 0; envIndex < release.environments.length; envIndex++) {
                const env = release.environments[envIndex];
                    let envTestResults = await testAPI.getTestResultDetailsForRelease(teamProject, release.id, env.id);
                    if (envTestResults.resultsForGroup.length > 0) {
                        for (let index = 0; index < envTestResults.resultsForGroup[0].results.length; index++) {
                            const test =  envTestResults.resultsForGroup[0].results[index];
                            if (testList.filter(e => e.testRun.id === `${test.testRun.id}`).length === 0) {
                                tl.debug(`Adding tests for test run ${test.testRun.id}`);
                                let run = await testAPI.getTestResults(teamProject, parseInt(test.testRun.id));
                                testList.push(...run);
                            } else {
                                tl.debug(`Skipping adding tests for test run ${test.testRun.id} as already added`);
                            }
                        }
                    } else {
                        tl.debug(`No tests associated with release ${release.id} environment ${env.name}`);
                    }
            }
            resolve(testList);
        } catch (err) {
            reject(err);
        }
    });
}

export function getTemplate(
        templateLocation: string,
        templatefile: string ,
        inlinetemplate: string
    ): Array<string> {
        agentApi.logDebug(`Using template mode ${templateLocation}`);
        var template;
        const handlebarIndicator = "{{";
        if (templateLocation === "File") {
            if (fs.existsSync(templatefile)) {
                agentApi.logInfo (`Loading template file ${templatefile}`);
                template = fs.readFileSync(templatefile, "utf8").toString();
            } else {
                agentApi.logError (`Cannot find template file ${templatefile}`);
                return template;
            }
        } else {
            agentApi.logInfo ("Using in-line template");
            template = inlinetemplate;
        }
        // we now only handle handlebar templates
        if (template.includes(handlebarIndicator)) {
            agentApi.logDebug("Loading handlebar template");
        }
        else {
            agentApi.logError("The template is not on handlebars format, load template has been skipped");
            template = "";
        }
        return template;
}

export async function getAllDirectRelatedWorkitems (
    workItemTrackingApi: IWorkItemTrackingApi,
    workItems: WorkItem[]
) {
    var relatedWorkItems = [...workItems]; // a clone
    for (let wiIndex = 0; wiIndex < workItems.length; wiIndex++) {
        var wi  = workItems[wiIndex];

        agentApi.logInfo(`Looking for parents and children of WI [${wi.id}]`);
        for (let relIndex = 0; relIndex <  wi.relations.length; relIndex++) {
            var relation  =  wi.relations[relIndex];
            if ((relation.attributes.name === "Child") ||
                (relation.attributes.name === "Parent")) {
                var urlParts = relation.url.split("/");
                var id = parseInt(urlParts[urlParts.length - 1]);
                if (!relatedWorkItems.find(element => element.id === id)) {
                    agentApi.logInfo(`Add ${relation.attributes.name} WI ${id}`);
                    relatedWorkItems.push(await workItemTrackingApi.getWorkItem(id, null, null, WorkItemExpand.All, null));
                } else {
                    agentApi.logInfo(`Skipping ${id} as already in the relations list`);
                }
            }
        }
    }

    return relatedWorkItems;

}

export async function getFullWorkItemDetails (
    workItemTrackingApi: IWorkItemTrackingApi,
    workItemRefs: ResourceRef[]
) {
    var workItemIds = workItemRefs.map(wi => parseInt(wi.id));
    let fullWorkItems: WorkItem[] = [];
    agentApi.logInfo(`Get details of [${workItemIds.length}] WIs`);
    if (workItemIds.length > 0) {
        var indexStart = 0;
        var indexEnd = (workItemIds.length > 200) ? 200 : workItemIds.length ;
        while ((indexEnd <= workItemIds.length) && (indexStart !== indexEnd)) {
            var subList = workItemIds.slice(indexStart, indexEnd);
            agentApi.logInfo(`Getting full details of WI batch from index: [${indexStart}] to [${indexEnd}]`);
            var subListDetails = await workItemTrackingApi.getWorkItems(subList, null, null, WorkItemExpand.All, null);
            agentApi.logInfo(`Adding [${subListDetails.length}] items`);
            fullWorkItems = fullWorkItems.concat(subListDetails);
            indexStart = indexEnd;
            indexEnd = ((workItemIds.length - indexEnd) > 200) ? indexEnd + 200 : workItemIds.length;
        }
    }
    return fullWorkItems;
}

// The Argument compareReleaseDetails is used in the template processing.  Renaming or removing will break the templates
export function processTemplate(
    template,
    workItems: WorkItem[],
    commits: Change[],
    buildDetails: Build,
    releaseDetails: Release,
    compareReleaseDetails: Release,
    customHandlebarsExtensionCode: string,
    customHandlebarsExtensionFile: string,
    customHandlebarsExtensionFolder: string,
    pullRequests: GitPullRequest[],
    globalBuilds: UnifiedArtifactDetails[],
    globalTests: TestCaseResult[],
    releaseTests: TestCaseResult[],
    relatedWorkItems: WorkItem[],
    compareBuildDetails: Build,
    currentStage: TimelineRecord
    ): string {

    var output = "";

    if (template.length > 0) {
        agentApi.logDebug("Processing template");
        agentApi.logDebug(`  WI: ${workItems.length}`);
        agentApi.logDebug(`  CS: ${commits.length}`);
        agentApi.logDebug(`  PR: ${pullRequests.length}`);
        agentApi.logDebug(`  Builds: ${globalBuilds.length}`);
        agentApi.logDebug(`  Global Tests: ${globalTests.length}`);
        agentApi.logDebug(`  Release Tests: ${releaseTests.length}`);
        agentApi.logDebug(`  Related WI: ${relatedWorkItems.length}`);

        // it is a handlebar template
        agentApi.logDebug("Processing handlebar template");
        const handlebars = require("handlebars");
        // load the extension library so it can be accessed in templates
        agentApi.logInfo("Loading handlebars-helpers extension");
        const helpers = require("handlebars-helpers")({
            handlebars: handlebars
        });

        // add a custom helper to expand json
        handlebars.registerHelper("json", function(context) {
            return JSON.stringify(context);
        });

        // add our helper to find children and parents
        handlebars.registerHelper("lookup_a_work_item", function (array, url) {
                var urlParts = url.split("/");
                var id = parseInt(urlParts[urlParts.length - 1]);
                return array.find(element => element.id === id);
            }
        );

        if (typeof customHandlebarsExtensionCode !== undefined && customHandlebarsExtensionCode && customHandlebarsExtensionCode.length > 0) {

            agentApi.logDebug(`Saving custom Handlebars code to file in folder ${customHandlebarsExtensionFolder}`);

            if (!customHandlebarsExtensionFolder || customHandlebarsExtensionFolder.length === 0) {
                // cannot use process.env.Agent_TempDirectory as only set on Windows agent, so build it up from the agent base
                // Note that the name is case sensitive on Mac and Linux
                customHandlebarsExtensionFolder = `${process.env.AGENT_WORKFOLDER}/_temp`;
            }

            agentApi.logInfo("Loading custom handlebars extension");
            writeFile(`${customHandlebarsExtensionFolder}/${customHandlebarsExtensionFile}.js`, customHandlebarsExtensionCode, true, false);
            var tools = require(`${customHandlebarsExtensionFolder}/${customHandlebarsExtensionFile}`);
            handlebars.registerHelper(tools);
        } else  {
            agentApi.logDebug(`No custom Handlebars code to process`);
        }

        // compile the template
        try {
            var handlebarsTemplate = handlebars.compile(template);

            // execute the compiled template
            output = handlebarsTemplate({
                "workItems": workItems,
                "commits": commits,
                "buildDetails": buildDetails,
                "releaseDetails": releaseDetails,
                "compareReleaseDetails": compareReleaseDetails,
                "pullRequests": pullRequests,
                "builds": globalBuilds,
                "tests": globalTests,
                "releaseTests": releaseTests,
                "relatedWorkItems": relatedWorkItems,
                "compareBuildDetails": compareBuildDetails
            });
            agentApi.logInfo( "Completed processing template");

        } catch (err) {
            agentApi.logError(`Error Processing handlebars [${err}]`);
        }
    } else {
        agentApi.logError( `Cannot load template file [${template}] or it is empty`);
    }  // if no template

    return output;
}

export function writeFile(filename: string, data: string, replaceFile: boolean, appendToFile: boolean) {
    if (replaceFile) {
        agentApi.logInfo(`Writing output file ${filename}`);
        fs.writeFileSync(filename, data, "utf8");
    } else {
        if (appendToFile) {
            agentApi.logInfo(`Appending output to file ${filename}`);
            fs.appendFileSync(filename, data, "utf8");
        } else {
            agentApi.logInfo(`Prepending output to file ${filename}`);
            var oldContent = "";
            if (fs.existsSync(filename)) {
                oldContent = fs.readFileSync(filename, "utf8");
            }
            fs.writeFileSync(filename, data, "utf8");
            fs.appendFileSync(filename, oldContent);
        }
    }
    agentApi.logInfo(`Finished writing output file ${filename}`);
}

export async function getLastSuccessfulBuildByStage(
    buildApi: IBuildApi,
    teamProject: string,
    stageName: string,
    buildId: number,
    buildDefId: number
)  {
    if (stageName.length === 0) {
        agentApi.logInfo ("No stage name provided, cannot find last successful build by stage");
        return {
            id: 0,
            stage: null
        };
    }
    let builds = await buildApi.getBuilds(teamProject, [buildDefId]);
    if (builds.length > 1 ) {
        for (let buildIndex = 0; buildIndex < builds.length; buildIndex++) {
            const build = builds[buildIndex];
            agentApi.logInfo (`Comparing ${build.id} against ${buildId}`);
            // force the cast to string as was getting a type mimatch
            if (build.id.toString() === buildId.toString()) {
                agentApi.logInfo("Ignore compare against self");
            } else {
                var lastGoodBuildId = 0;
                let timeline = await buildApi.getBuildTimeline(teamProject, build.id);
                if (timeline && timeline.records) {
                    for (let timelineIndex = 0; timelineIndex < timeline.records.length; timelineIndex++) {
                        const record  = timeline.records[timelineIndex];
                        if (record.type === "Stage") {
                            if ((record.name === stageName || record.identifier === stageName) && 
                                (record.state.toString() === "2" || record.state.toString() === "completed") && // completed
                                (record.result.toString() === "0" || record.result.toString() === "succeeded")) { // succeeded
                                    agentApi.logInfo (`Found required stage ${record.name} in the completed and successful state in build ${build.id}`);
                                return {
                                    id: build.id,
                                    stage: record
                                };
                            }
                        }
                    }
                } else {
                    agentApi.logInfo("Skipping check as no timeline available for this build");
                }
            }
        }
    }
    return {
        id: 0,
        stage: null
    };
}

export async function generateReleaseNotes(
    pat: string,
    tpcUri: string,
    teamProject: string,
    buildId: number,
    releaseId: number,
    releaseDefinitionId: number,
    overrideStageName: string,
    environmentName: string,
    activateFix: string,
    templateLocation: string,
    templateFile: string,
    inlineTemplate: string,
    outputFile: string,
    outputVariableName: string,
    sortWi: boolean,
    showOnlyPrimary: boolean,
    replaceFile: boolean,
    appendToFile: boolean,
    getParentsAndChildren: boolean,
    searchCrossProjectForPRs: boolean,
    stopOnRedeploy: boolean,
    customHandlebarsExtensionCode: string,
    customHandlebarsExtensionFile: string,
    customHandlebarsExtensionFolder: string,
    gitHubPat: string,
    bitbucketUser: string,
    bitbucketSecret: string,
    dumpPayloadToConsole: boolean,
    dumpPayloadToFile: boolean,
    dumpPayloadFileName: string,
    checkStage: boolean): Promise<number> {
        return new Promise<number>(async (resolve, reject) => {

            if (!gitHubPat) {
                // a check to make sure we don't get a null
                gitHubPat = "";
            }

            let credentialHandler: vstsInterfaces.IRequestHandler = getCredentialHandler(pat);
            let organisation = new webApi.WebApi(tpcUri, credentialHandler);
            var releaseApi: IReleaseApi = await organisation.getReleaseApi();
            var buildApi: IBuildApi = await organisation.getBuildApi();
            var gitApi: IGitApi = await organisation.getGitApi();
            var testApi: ITestApi = await organisation.getTestApi();
            var workItemTrackingApi: IWorkItemTrackingApi = await organisation.getWorkItemTrackingApi();
            var tfvcApi: ITfvcApi = await organisation.getTfvcApi();

            // the result containers
            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];
            var globalPullRequests: GitPullRequest[] = [];
            var globalBuilds: UnifiedArtifactDetails[] = [];
            var globalTests: TestCaseResult[] = [];
            var releaseTests: TestCaseResult[] = [];

            var mostRecentSuccessfulDeploymentName: string = "";
            let mostRecentSuccessfulDeploymentRelease: Release;
            let mostRecentSuccessfulBuild: Build;

            var currentRelease: Release;
            var currentBuild: Build;
            var currentStage: TimelineRecord;

            if ((releaseId === undefined) || !releaseId) {
                agentApi.logInfo("Getting the current build details");
                currentBuild = await buildApi.getBuild(teamProject, buildId);

                if (!currentBuild) {
                    agentApi.logError (`Unable to locate the current build with id ${buildId} in the project ${teamProject}`);
                    reject (-1);
                    return;
                }

                if (checkStage) {
                    var stageName = tl.getVariable("System.StageName");
                    if (overrideStageName && overrideStageName.length > 0) {
                        agentApi.logInfo(`Overriding current stage '${stageName}' with '${overrideStageName}'`);
                        stageName = overrideStageName;
                    }
                    agentApi.logInfo (`Getting items associated the builds since the last successful build to the stage '${stageName}'`);
                    var successfulStageDetails = await getLastSuccessfulBuildByStage(buildApi, teamProject, stageName, buildId, currentBuild.definition.id);
                    var lastGoodBuildId = successfulStageDetails.id;
                    if (lastGoodBuildId !== 0) {
                        console.log(`Getting the details between ${lastGoodBuildId} and ${buildId}`);
                        currentStage = successfulStageDetails.stage;

                        mostRecentSuccessfulBuild = await buildApi.getBuild(teamProject, lastGoodBuildId);

                        // There is only a workaround for Git but not for TFVC :(
                        if (mostRecentSuccessfulBuild.repository.type === "TfsGit") {
                            agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                            let currentBuild = await buildApi.getBuild(teamProject, buildId);
                            let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(organisation, mostRecentSuccessfulBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
                            globalCommits = commitInfo.commits;
                            globalWorkItems = commitInfo.workItems;
                        } else {
                            // Fall back to original behavior
                            globalCommits = await buildApi.getChangesBetweenBuilds(teamProject, lastGoodBuildId, buildId);
                            globalWorkItems = await buildApi.getWorkItemsBetweenBuilds(teamProject, lastGoodBuildId, buildId);
                        }

                       globalTests = await getTestsForBuild(testApi, teamProject, buildId);
                    } else {
                        console.log("There has been no past successful build for this stage, so we can just get details from this build");
                        globalCommits = await buildApi.getBuildChanges(teamProject, buildId);
                        globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId);
                    }
                } else {
                    agentApi.logInfo (`Getting items associated with only the current build`);
                    globalCommits = await buildApi.getBuildChanges(teamProject, buildId);
                    globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId);
                }
                console.log("Get the file details associated with the commits");
                globalCommits = await enrichChangesWithFileDetails(gitApi, tfvcApi, globalCommits, gitHubPat);
                console.log("Get any test details associated with the build");
                globalTests = await getTestsForBuild(testApi, teamProject, buildId);

            } else {
                environmentName = (overrideStageName || environmentName).toLowerCase();

                agentApi.logInfo("Getting the current release details");
                currentRelease = await releaseApi.getRelease(teamProject, releaseId);

                agentApi.logInfo(`Show associated items for primary artifact only is set to ${showOnlyPrimary}`);

                // check of redeploy
                if (stopOnRedeploy === true) {
                    if ( getDeploymentCount(currentRelease.environments, environmentName) > 1) {
                        agentApi.logWarn(`Skipping release note generation as this deploy is a re-deployment`);
                        resolve(-1);
                        return;
                    }
                }

                if (!currentRelease) {
                    agentApi.logError(`Unable to locate the current release with id ${releaseId}`);
                    resolve(-1);
                    return;
                }

                var environmentId = getReleaseDefinitionId(currentRelease.environments, environmentName);

                let mostRecentSuccessfulDeployment = await getMostRecentSuccessfulDeployment(releaseApi, teamProject, releaseDefinitionId, environmentId);
                let isInitialRelease = false;

                agentApi.logInfo(`Getting all artifacts in the current release...`);
                var arifactsInThisRelease = getSimpleArtifactArray(currentRelease.artifacts);
                agentApi.logInfo(`Found ${arifactsInThisRelease.length}`);

                let arifactsInMostRecentRelease: SimpleArtifact[] = [];
                if (mostRecentSuccessfulDeployment) {
                    // Get the release that the deployment was a part of - This is required for the templating.
                    mostRecentSuccessfulDeploymentRelease = await releaseApi.getRelease(teamProject, mostRecentSuccessfulDeployment.release.id);
                    agentApi.logInfo(`Getting all artifacts in the most recent successful release [${mostRecentSuccessfulDeployment.release.name}]...`);
                    arifactsInMostRecentRelease = getSimpleArtifactArray(mostRecentSuccessfulDeployment.release.artifacts);
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
                                        var tests: TestCaseResult[];

                                        // Only get the commits and workitems if the builds are different
                                        if (isInitialRelease) {
                                            agentApi.logInfo(`This is the first release so checking what commits and workitems are associated with artifacts`);
                                            var builds = await buildApi.getBuilds(artifactInThisRelease.sourceId, [parseInt(artifactInThisRelease.buildDefinitionId)]);
                                            commits = [];
                                            workitems = [];

                                            for (var build of builds) {
                                                try {
                                                    agentApi.logInfo(`Getting the details of ${build.id}`);
                                                    var buildCommits = await buildApi.getBuildChanges(teamProject, build.id);
                                                    commits.push(...buildCommits);
                                                    var buildWorkitems = await buildApi.getBuildWorkItemsRefs(teamProject, build.id);
                                                    workitems.push(...buildWorkitems);
                                                } catch (err) {
                                                    agentApi.logWarn(`There was a problem getting the details of the build ${err}`);
                                                }
                                            }
                                        } else if (artifactInMostRecentRelease.buildId !== artifactInThisRelease.buildId) {
                                            agentApi.logInfo(`Checking what commits and workitems have changed from [${artifactInMostRecentRelease.buildNumber}][ID ${artifactInMostRecentRelease.buildId}] => [${artifactInThisRelease.buildNumber}] [ID ${artifactInThisRelease.buildId}]`);

                                            try {
                                                // Check if workaround for issue #349 should be used
                                                if (!activateFix) {
                                                    agentApi.logInfo("Defaulting on the workaround for build API limitation (see issue #349 set 'ReleaseNotes.Fix349=false' to disable)");
                                                    activateFix = "true";
                                                }

                                                if (activateFix && activateFix.toLowerCase() === "true") {
                                                    let baseBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId));
                                                    agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                                                    // There is only a workaround for Git but not for TFVC :(
                                                    if (baseBuild.repository.type === "TfsGit") {
                                                        let currentBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInThisRelease.buildId));
                                                        let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(organisation, baseBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
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

                                                // enrich what we have with file names
                                                if (commits) {
                                                    commits = await enrichChangesWithFileDetails(gitApi, tfvcApi, commits, gitHubPat);
                                                }

                                            } catch (err) {
                                                agentApi.logWarn(`There was a problem getting the details of the CS/WI for the build ${err}`);
                                            }
                                        } else {
                                            commits = [];
                                            workitems = [];
                                            agentApi.logInfo(`Build for artifact [${artifactInThisRelease.artifactAlias}] has not changed.  Nothing to do`);
                                        }

                                        // look for any test in the current build
                                        agentApi.logInfo(`Getting test associated with the latest build [${artifactInThisRelease.buildId}]`);
                                        tests = await getTestsForBuild(testApi, teamProject, parseInt(artifactInThisRelease.buildId));

                                        if (tests) {
                                            agentApi.logInfo(`Found ${tests.length} test associated with the build [${artifactInThisRelease.buildId}] adding any not already in the global test list to the list`);
                                            // we only want to add unique items
                                            globalTests = addUniqueTestToArray(globalTests, tests);
                                        }

                                        // get artifact details for the unified output format
                                        let artifact = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInThisRelease.buildId));
                                        agentApi.logInfo(`Adding the build [${artifact.id}] and its association to the unified results object`);
                                        let fullBuildWorkItems = await getFullWorkItemDetails(workItemTrackingApi, workitems);
                                        globalBuilds.push(new UnifiedArtifactDetails(artifact, commits, fullBuildWorkItems, tests));

                                        if (commits) {
                                            globalCommits = globalCommits.concat(commits);
                                        }

                                        if (workitems) {
                                            globalWorkItems = globalWorkItems.concat(workitems);
                                        }

                                        agentApi.logInfo(`Detected ${commits.length} commits/changesets and ${workitems.length} workitems between the current build and the last successful one`);
                                        agentApi.logInfo(`Detected ${tests.length} tests associated within the current build.`);
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

                // checking for test associated with the release
                releaseTests = await getTestsForRelease(testApi, teamProject, currentRelease);
                // we only want to add unique items
                globalTests = addUniqueTestToArray(globalTests, releaseTests);

            }

            // remove duplicates
            agentApi.logInfo("Removing duplicate Commits from master list");
            globalCommits = removeDuplicates(globalCommits);
            agentApi.logInfo("Removing duplicate WorkItems from master list");
            globalWorkItems = removeDuplicates(globalWorkItems);

            let expandedGlobalCommits = await expandTruncatedCommitMessages(organisation, globalCommits, gitHubPat, bitbucketUser, bitbucketSecret);

            if (!expandedGlobalCommits || expandedGlobalCommits.length !== globalCommits.length) {
                agentApi.logError("Failed to expand the global commits.");
                resolve(-1);
                return;
            }

            // get an array of workitem ids
            let fullWorkItems = await getFullWorkItemDetails(workItemTrackingApi, globalWorkItems);

            let relatedWorkItems = [];

            if (getParentsAndChildren) {
                agentApi.logInfo("Getting parents and children of WorkItems");
                relatedWorkItems = await getAllDirectRelatedWorkitems(workItemTrackingApi, fullWorkItems);
            }

            agentApi.logInfo(`Total build artifacts: [${globalBuilds.length}]`);
            agentApi.logInfo(`Total commits: [${globalCommits.length}]`);
            agentApi.logInfo(`Total workitems: [${globalWorkItems.length}]`);
            agentApi.logInfo(`Total related workitems: [${relatedWorkItems.length}]`);
            agentApi.logInfo(`Total release tests: [${releaseTests.length}]`);
            agentApi.logInfo(`Total tests: [${globalTests.length}]`);

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

            try {
                var allPullRequests: GitPullRequest[] = await getPullRequests(gitApi, prProjectFilter);
                if (allPullRequests && (allPullRequests.length > 0)) {
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
            } catch (error) {
                agentApi.logWarn(`Could not get details of any PR an error was seen: ${error}`);
            }

            // remove duplicates
            globalPullRequests = globalPullRequests.filter((thing, index, self) =>
                index === self.findIndex((t) => (
                t.pullRequestId === thing.pullRequestId
                ))
            );

            agentApi.logInfo(`Total Pull Requests: [${globalPullRequests.length}]`);

            dumpJsonPayload(
                dumpPayloadToConsole,
                dumpPayloadToFile,
                dumpPayloadFileName,
                {
                    workItems: fullWorkItems,
                    commits: globalCommits,
                    pullRequests: globalPullRequests,
                    tests: globalTests,
                    builds: globalBuilds,
                    relatedWorkItems: relatedWorkItems,
                    releaseDetails: currentRelease,
                    compareReleaseDetails: mostRecentSuccessfulDeploymentRelease,
                    releaseTests: releaseTests,
                    buildDetails: currentBuild,
                    compareBuildDetails: mostRecentSuccessfulBuild,
                    currentStage: currentStage
                });

            var template = getTemplate (templateLocation, templateFile, inlineTemplate);
            if ((template) && (template.length > 0)) {
                var outputString = processTemplate(
                    template,
                    fullWorkItems,
                    globalCommits,
                    currentBuild,
                    currentRelease,
                    mostRecentSuccessfulDeploymentRelease,
                    customHandlebarsExtensionCode,
                    customHandlebarsExtensionFile,
                    customHandlebarsExtensionFolder,
                    globalPullRequests,
                    globalBuilds,
                    globalTests,
                    releaseTests,
                    relatedWorkItems,
                    mostRecentSuccessfulBuild,
                    currentStage);

                writeFile(outputFile, outputString, replaceFile, appendToFile);

                agentApi.writeVariable(outputVariableName, outputString.toString());

                resolve(0);
            } else {
                reject ("Missing template file");
            }
        });
}

function dumpJsonPayload(dumpPayloadToConsole: boolean, dumpPayloadToFile: boolean, fileName: string, payload) {
    let data = JSON.stringify(payload);

    if (dumpPayloadToConsole) {
        agentApi.logInfo("Start of payload data dump");
        agentApi.logInfo(data);
        agentApi.logInfo("End of payload data dump");
    }

    if (dumpPayloadToFile) {
        if (fileName) {
            agentApi.logInfo(`Writing payload data to file ${fileName}`);
            fs.writeFileSync(fileName, data);
        } else {
            agentApi.logWarn(`No payload dump file name provided`);
        }
    }
}

function removeDuplicates(array: any[]): any[] {
    array = array.filter((thing, index, self) =>
    index === self.findIndex((t) => (
    t.id === thing.id
    )));
    return array;
}