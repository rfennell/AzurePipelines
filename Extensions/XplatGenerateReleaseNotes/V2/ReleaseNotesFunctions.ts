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
    workitems: ResourceRef[];
    tests: TestCaseResult[];
    constructor ( build: Build, commits: Change[], workitems: ResourceRef[], tests: TestCaseResult[]) {
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
import { PersonalAccessTokenCredentialHandler } from "typed-rest-client/Handlers";
import tl = require("azure-pipelines-task-lib/task");
import { ReleaseEnvironment, Artifact, Deployment, DeploymentStatus, Release } from "azure-devops-node-api/interfaces/ReleaseInterfaces";
import { IAgentSpecificApi, AgentSpecificApi } from "./agentSpecific";
import { IReleaseApi } from "azure-devops-node-api/ReleaseApi";
import { IRequestHandler } from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import * as webApi from "azure-devops-node-api/WebApi";
import fs  = require("fs");
import { Build, Change } from "azure-devops-node-api/interfaces/BuildInterfaces";
import { IGitApi, GitApi } from "azure-devops-node-api/GitApi";
import { ResourceRef } from "azure-devops-node-api/interfaces/common/VSSInterfaces";
import { GitCommit, GitPullRequest, GitPullRequestQueryType, GitPullRequestSearchCriteria, PullRequestStatus } from "azure-devops-node-api/interfaces/GitInterfaces";
import { WebApi } from "azure-devops-node-api";
import { TestApi } from "azure-devops-node-api/TestApi";
import { timeout } from "q";
import { TestCaseResult } from "azure-devops-node-api/interfaces/TestInterfaces";
import { IWorkItemTrackingApi } from "azure-devops-node-api/WorkItemTrackingApi";
import { WorkItemExpand, WorkItem, ArtifactUriQuery } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";
import { ITfvcApi } from "azure-devops-node-api/TfvcApi";
import * as issue349 from "./Issue349Workaround";
import { ITestApi } from "azure-devops-node-api/TestApi";
import { IBuildApi } from "azure-devops-node-api/BuildApi";
import * as vstsInterfaces from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";

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

export async function expandTruncatedCommitMessages(restClient: WebApi, globalCommits: Change[], pat: string): Promise<Change[]> {
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
                            let auth = new PersonalAccessTokenCredentialHandler(pat);

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
                        agentApi.logWarn(`The most common reason for this failure is that the GitHub Repo is private and a Personal Access Token giving read access needs to be passed as a parameter to this task`);
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
                        var parts = url.parse(change.location);
                        if (parts.host === "dev.azure.com") {
                            let gitDetails = await gitApi.getChanges(change.id, parts.path.split("/")[6]);
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
export function getCredentialHandler(): IRequestHandler {
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
            agentApi.logInfo (`Loading template file ${templatefile}`);
            template = fs.readFileSync(templatefile, "utf8").toString();
        } else {
            agentApi.logInfo ("Using in-line template");
            template = inlinetemplate;
        }
        // handlebar templates won't be processed line-by-line so don't split them
        if (template.includes(handlebarIndicator)) {
            agentApi.logDebug("Loading handlebar template");
        }
        else {
            agentApi.logDebug("Loading legacy template");
            // it appears as single line we need to split it out
            template = template.split("\n");
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

        agentApi.logInfo(`Looking for parents and children of ${wi.id}`);
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
    emptySetText,
    delimiter,
    fieldEquality,
    anyFieldContent,
    customHandlebarsExtensionCode: string,
    customHandlebarsExtensionFile: string,
    customHandlebarsExtensionFolder: string,
    prDetails,
    pullRequests: GitPullRequest[],
    globalBuilds: UnifiedArtifactDetails[],
    globalTests: TestCaseResult[],
    releaseTests: TestCaseResult[],
    relatedWorkItems: WorkItem[]
    ): string {

    var widetail = undefined;
    var csdetail = undefined;
    var lastBlockStartIndex;
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
        // if it's an array, it's a legacy template
        if (Array.isArray(template)) {

            agentApi.logDebug("Processing legacy template");

            // create our work stack and initialise
            var modeStack = [];

            addStackItem (null, modeStack, Mode.BODY, -1);

            // process each line
            for (var index = 0; index < template.length; index++) {
               agentApi.logDebug(`${addSpace(modeStack.length + 1)} Processing Line No: ${(index + 1)}`);
               var line = template[index];
               // agentApi.logDebug("Line: " + line);
               // get the line mode (if any)
               var mode = getMode(line);
               var wiFilter = getWIModeTags(line, delimiter, fieldEquality);
               var csFilter = getCSFilter(line);

               if (mode !== Mode.BODY) {
                   // is there a mode block change
                  if (getMode(modeStack[modeStack.length - 1].BlockMode) === mode) {
                      // this means we have reached the end of a block
                      // need to work out if there are more items to process
                      // or the end of the block
                      var queue = modeStack[modeStack.length - 1].BlockQueue;
                      if (queue.length > 0) {
                          // get the mode items and initialise
                          // the variables exposed to the template
                          var item = queue.shift();
                          // reset the index to process the block
                          index = modeStack[modeStack.length - 1].Index;
                          switch (mode) {
                            case Mode.WI :
                                agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting next workitem ${item.id}`);
                                widetail = item; // should filter
                                break;
                            case Mode.CS :
                                if (csdetail.type.toLowerCase() === "tfsgit") {
                                    // Git mode
                                    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting next commit ${item.id}`);
                                } else {
                                    // TFVC mode
                                    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting next changeset ${item.id}`);
                                }
                                 csdetail = item;
                                 break;
                          } // end switch
                      } else {
                          // end of block and no more items, so exit the block
                          var blockMode = modeStack.pop().BlockMode;
                          agentApi.logDebug (`${addSpace(modeStack.length + 1)} Ending block ${blockMode}`);
                      }
                  } else {
                      // this a new block to add the stack
                      // need to get the items to process and place them in a queue
                      agentApi.logDebug (`${addSpace(modeStack.length + 1)} Starting block ${line}`);
                      // set the index to jump back to
                      lastBlockStartIndex = index;
                      switch (mode) {
                          case Mode.WI:
                            // store the block and load the first item
                            // Need to check if we are in tag mode
                            var modeArray = [];
                            if (wiFilter.tags.length > 0 || wiFilter.fields.length > 0) {
                                widetail = undefined;
                                var parts;
                                var okToAdd;
                                workItems.forEach(wi => {
                                    agentApi.logDebug (`${addSpace(modeStack.length + 2)} Checking WI ${wi.id} with tags '${wi.fields["System.Tags"]}' against tags '${wiFilter.tags.sort().join("; ")}' and fields '${wiFilter.fields.sort().join("; ")}' using comparison filter '${wiFilter.modifier}'`);
                                    switch (wiFilter.modifier) {
                                        case Modifier.All:
                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Using ALL filter`);
                                            if (wiFilter.tags.length > 0) {
                                                if ((wi.fields["System.Tags"] !== undefined) &&
                                                    (wi.fields["System.Tags"].toUpperCase() === wiFilter.tags.join("; ").toUpperCase())) {
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 4)} Tags match, need to check fields`);
                                                    okToAdd = true;
                                                } else {
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 4)} Tags do not match, no need to check fields`);
                                                    okToAdd = false;
                                                }
                                            } else {
                                                agentApi.logDebug (`${addSpace(modeStack.length + 4)} No tags in filter to match, need to check fields`);
                                                okToAdd = true;
                                            }
                                            if (okToAdd && wiFilter.fields.length > 0) {
                                                for (let field of wiFilter.fields) {
                                                    parts = field.split("=");
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 4)} Comparing field '${parts[0]}' contents '${wi.fields[parts[0]]}' to '${parts[1]}'`);
                                                    if (parts[1] === anyFieldContent) {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} The contents match is the 'any data value`);
                                                        if (wi.fields[parts[0]] === undefined) {
                                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field does not exist`);
                                                            okToAdd = false;
                                                            break;
                                                        } else {
                                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field exists`);
                                                        }
                                                    } else if (wi.fields[parts[0]] !== parts[1]) {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field does not match`);
                                                        okToAdd = false;
                                                        break;
                                                    } else {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field matches`);
                                                    }
                                                }
                                            }
                                            if (okToAdd) {
                                                agentApi.logDebug (`${addSpace(modeStack.length + 4)} Adding WI ${wi.id} as all tags and fields match`);
                                                modeArray.push(wi);
                                            }
                                            break;
                                        case Modifier.ANY:
                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Using ANY filter`);
                                            okToAdd = false;
                                            if ((wi.fields["System.Tags"] !== undefined) && (wiFilter.tags.length > 0)) {
                                                for (let tag of wiFilter.tags) {
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 4)} Checking tag ${tag}`);
                                                    if (wi.fields["System.Tags"].toUpperCase().indexOf(tag.toUpperCase()) !== -1) {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} Found match on tag`);
                                                        okToAdd = true;
                                                        break;
                                                    } else {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} No match on tag`);
                                                    }
                                                }
                                            } else {
                                                agentApi.logDebug (`${addSpace(modeStack.length + 4)} No tags to check, checking fields`);
                                            }
                                            if (okToAdd === false) {
                                                for (let field of wiFilter.fields) {
                                                    parts = field.split("=");
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 4)} Comparing field '${parts[0]}' contents '${wi.fields[parts[0]]}' to '${parts[1]}'`);
                                                    if (parts[1] === anyFieldContent) {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} The contents match is the 'any data value`);
                                                        if (wi.fields[parts[0]] !== undefined) {
                                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field exist`);
                                                            okToAdd = true;
                                                            break;
                                                        } else {
                                                            agentApi.logDebug (`${addSpace(modeStack.length + 4)} Field does not exist`);
                                                        }
                                                    } else if (wi.fields[parts[0]] !== undefined && wi.fields[parts[0]] === parts[1]) {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} Found match on field`);
                                                        okToAdd = true;
                                                        break;
                                                    } else {
                                                        agentApi.logDebug (`${addSpace(modeStack.length + 4)} No match on field`);
                                                    }
                                                }
                                            }
                                            if (okToAdd) {
                                                agentApi.logDebug (`${addSpace(modeStack.length + 4)} Adding WI ${wi.id} as at least one tag or field matches`);
                                                modeArray.push(wi);
                                            }
                                            break;
                                        default:
                                            agentApi.logWarn (`${addSpace(modeStack.length + 4)} Invalid filter passed, skipping WI ${wi.id}`);
                                    }
                                });
                            } else {
                                agentApi.logDebug (`${addSpace(modeStack.length + 4)} Adding all WI as no tag or fields filter`);
                                modeArray = workItems;
                            }
                            agentApi.logDebug (`${addSpace(modeStack.length + 1)} There are ${modeArray.length} WI to add`);
                            addStackItem (modeArray, modeStack, line, index);
                            // now we have stack item we can get the first item
                            if (modeStack[modeStack.length - 1].BlockQueue.length > 0) {
                                widetail = modeStack[modeStack.length - 1].BlockQueue.shift();
                                agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting first workitem ${widetail.id}`);
                            } else {
                                widetail = undefined;
                            }
                            break;
                          case Mode.CS:
                            var filterArray = [];
                            if (csFilter.trim().length > 0) {
                                var regexp = new RegExp(csFilter);
                                agentApi.logDebug(`${addSpace(modeStack.length + 1)} Regex filter '${csFilter}' used to filter CS`);
                                commits.forEach(cs => {
                                    if (cs.message.length > 0 ) {
                                        agentApi.logDebug(`${addSpace(modeStack.length + 1)} Regex test against '${cs.message}'`);
                                        if (regexp.test(cs.message)) {
                                            agentApi.logDebug(`${addSpace(modeStack.length + 1)} Match found adding`);
                                            filterArray.push(cs);
                                        } else {
                                            agentApi.logDebug(`${addSpace(modeStack.length + 1)} No match found, not adding`);
                                        }
                                    } else {
                                        agentApi.logDebug(`${addSpace(modeStack.length + 1)} Cannot do regex test as empty commit message`);
                                    }
                                });
                                // store the block and load the first item
                                agentApi.logDebug (`${addSpace(modeStack.length + 1)} There are ${filterArray.length} matched CS out of ${commits.length} to add`);
                                addStackItem (filterArray, modeStack, line, index);
                            } else {
                                agentApi.logDebug(`${addSpace(modeStack.length + 1)} No regex filter used to filter CS`);
                                // store the block and load the first item
                                addStackItem (commits, modeStack, line, index);
                            }
                            // now we have stack item we can get the first item
                            if (modeStack[modeStack.length - 1].BlockQueue.length > 0) {
                                 csdetail = modeStack[modeStack.length - 1].BlockQueue.shift();
                                 if (csdetail.type.toLowerCase() === "tfsgit") {
                                    // Git mode
                                    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting first commit ${csdetail.id}`);
                                 } else {
                                    // TFVC mode
                                    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting first changeset ${csdetail.id}`);
                                 }
                            } else {
                                  csdetail = undefined;
                            }
                             break;
                        } // end switch
                    }
                } else {
                    // agentApi.logDebug(`${addSpace(modeStack.length + 1)} Mode != BODY`);
                    if ( line.trim().length === 0) {
                        // we have a blank line, we can't eval this
                        agentApi.logDebug(`${addSpace(modeStack.length + 1)} Outputing a blank line`);
                        output += "\n";
                    } else {
                        if (((getMode(modeStack[modeStack.length - 1].BlockMode) === Mode.WI) && (widetail === undefined)) ||
                           ((getMode(modeStack[modeStack.length - 1].BlockMode) === Mode.CS) && (csdetail === undefined))) {
                            // # there is no data to expand
                            agentApi.logDebug(`${addSpace(modeStack.length + 1)} No WI or CS so outputing emptySetText`);
                            output += emptySetText;
                        } else {
                            agentApi.logDebug(`${addSpace(modeStack.length + 1)} Nothing to expand, just process the line`);
                            // nothing to expand just process the line
                            var fixedline = fixline (line);
                            var processedLine = eval(fixedline);
                            var lines = processedLine.split("\r\n");
                            for ( var i = 0; i < lines.length; i ++) {
                                output += lines[i];
                            }
                        }
                        // always add a line feed
                        output += "\n";
                    }
                }
            }  // loop
        } else {
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

            var customHandlebarsExtensionFile = "customHandlebarsExtension";
            // cannot use process.env.Agent_TempDirectory as only set on Windows agent, so build it up from the agent base
            // Note that the name is case sensitive on Mac and Linux
            var customHandlebarsExtensionFolder = `${process.env.AGENT_WORKFOLDER}/_temp`;
            agentApi.logDebug(`Saving custom handles code to file in folder ${customHandlebarsExtensionFolder}`);

            if (typeof customHandlebarsExtensionCode !== undefined && customHandlebarsExtensionCode && customHandlebarsExtensionCode.length > 0) {
                agentApi.logInfo("Loading custom handlebars extension");
                writeFile(`${customHandlebarsExtensionFolder}/${customHandlebarsExtensionFile}.js`, customHandlebarsExtensionCode, true, false);
                var tools = require(`${customHandlebarsExtensionFolder}/${customHandlebarsExtensionFile}`);
                handlebars.registerHelper(tools);
            }

            // compile the template
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
                "relatedWorkItems": relatedWorkItems
             });
        }

        agentApi.logInfo( "Completed processing template");
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

// There is no WI in this list as they are dynamic as they can include tags
export const Mode = {
     BODY : "BODY",
     CS : "CS",
     WI : "WI"
};

export const Modifier = {
    All : "ALL",
    ANY : "ANY"
};

export class WiFilter {
    modifier;
    tags;
    fields;
}

export function getMode (line): string {
     var mode = Mode.BODY;
     if (line !== undefined ) {
        line = line.trim().toUpperCase();
        if (line.startsWith("@@WILOOP") && line.endsWith("@@")) {
            mode = Mode.WI;
        }
        if (line.startsWith("@@CSLOOP") && line.endsWith("@@") ) {
            mode = Mode.CS;
        }
    }
    return mode;
}

export function getCSFilter (line): string {
    line = line.trim();
    var filter = "";
    if (line.startsWith("@@CS") && line.endsWith("@@") ) {
        line = line.replace(/@@/g, ""); // have to use regex form of replace else only first replaced
        var match = line.match(/(\[.*?\])/g);
        if (match !== null) {
            filter = match.toString().substring(1, match.toString().length - 1);
        }
    }
    return filter;
}

export function getWIModeTags (line, tagDelimiter, fieldEquivalent): WiFilter {
    line = line.trim();
    var filter = new WiFilter();
    filter.modifier = Modifier.All;
    filter.tags = [];
    filter.fields = [];
    if (line.startsWith("@@WI") && line.endsWith("@@") ) {
        line = line.replace(/@@/g, ""); // have to use regex form of replace else only first replaced
        var match = line.match(/(\[.*?\])/g);
        if (match !== null && match.toString().toUpperCase() === "[ANY]") {
            filter.modifier = Modifier.ANY;
        }
        var parts = line.split(tagDelimiter);
        if (parts.length > 1) {
            parts.splice(0, 1); // return the tags
            parts.forEach(part => {
                if (part.indexOf(fieldEquivalent) !== -1 ) {
                    filter.fields.push(part.replace(fieldEquivalent, "="));
                } else {
                    filter.tags.push(part.toUpperCase());
                }
            });
        }
    }
    return filter;
}

function addStackItem (
        items,
        modeStack,
        blockMode,
        index
    ) {
    // Create a queue of the items
    var queue = [];
    // add each item to the queue if we have any
    if (items) {
        for (let item of items) {
            queue.push(item);
        }
    }

    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Added ${queue.length} items to queue for ${blockMode}`);
    // place it on the stack with the blocks mode and start line index
    modeStack.push({"BlockMode": blockMode.trim(), "BlockQueue": queue, "Index": index});
}

export function addSpace (indent): string {
    var size = 3;
    var upperBound = size * indent;
    var padding = "";
    for (var i = 1 ; i < upperBound  ; i++) {
        padding += " ";
    }
    return padding;
}

// Take a template line and convert it to something we can eval
export function fixline (line: string ): string {
    // we can't use simple string replace as it only replaces the first instance
    // could use the regex form but think this is easier to read in the future
    if (line.includes("${")) {
        return "\"" + line.trim().split("${").join("\" + ").split("}").join(" + \"") + "\"";
    } else {
        // we only expand the line if the ${ in it. This fixes problems with incorrectly expand {}
        return "\"" + line.trim() + "\"";
    }
}

export async function generateReleaseNotes(
    tpcUri: string,
    teamProject: string,
    templateLocation: string,
    templateFile: string,
    inlineTemplate: string,
    outputFile: string,
    outputVariableName: string,
    emptyDataset: string,
    delimiter: string,
    anyFieldContent: string,
    showOnlyPrimary: boolean,
    replaceFile: boolean,
    appendToFile: boolean,
    getParentsAndChildren: boolean,
    searchCrossProjectForPRs: boolean,
    fieldEquality: string,
    stopOnRedeploy: boolean,
    sortWi: boolean,
    customHandlebarsExtensionCode: string,
    customHandlebarsExtensionFile: string,
    customHandlebarsExtensionFolder: string,
    gitHubPat: string,
    dumpPayload: boolean,
    dumpPayloadFileName: string): Promise<number> {
        return new Promise<number>(async (resolve, reject) => {

            if (delimiter === null) {
                agentApi.logInfo(`No delimiter passed, setting a default of :`);
                delimiter = ":";
            }            if (fieldEquality === null) {
                agentApi.logInfo(`No fieldEquality passed, setting a default of =`);
                delimiter = "=";
            }

            if (fieldEquality === delimiter) {
                agentApi.logError (`The delimiter and field equality parameters cannot be the same, please change one. The usual defaults a : and = respectively`);
            }

            if (!gitHubPat) {
                // a check to make sure we don't get a null
                gitHubPat = "";
            }

            let credentialHandler: vstsInterfaces.IRequestHandler = getCredentialHandler();
            let vsts = new webApi.WebApi(tpcUri, credentialHandler);
            var releaseApi: IReleaseApi = await vsts.getReleaseApi();
            var buildApi: IBuildApi = await vsts.getBuildApi();
            var gitApi: IGitApi = await vsts.getGitApi();
            var testApi: ITestApi = await vsts.getTestApi();
            var workItemTrackingApi: IWorkItemTrackingApi = await vsts.getWorkItemTrackingApi();
            var tfvcApi: ITfvcApi = await vsts.getTfvcApi();

            // the result containers
            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];
            var globalPullRequests: GitPullRequest[] = [];
            var globalBuilds: UnifiedArtifactDetails[] = [];
            var globalTests: TestCaseResult[] = [];
            var releaseTests: TestCaseResult[] = [];

            var mostRecentSuccessfulDeploymentName: string = "";
            let mostRecentSuccessfulDeploymentRelease: Release;

            var currentRelease: Release;
            var currentBuild: Build;

            if (tl.getVariable("Release.ReleaseId") === undefined) {
                agentApi.logInfo("Getting the current build details");
                let buildId: number = parseInt(tl.getVariable("Build.BuildId"));
                currentBuild = await buildApi.getBuild(teamProject, buildId);

                if (!currentBuild) {
                    agentApi.logError (`Unable to locate the current build with id ${buildId} in the project ${teamProject}`);
                    reject (-1);
                    return;
                }

                globalCommits = await buildApi.getBuildChanges(teamProject, buildId);
                globalCommits = await enrichChangesWithFileDetails(gitApi, tfvcApi, globalCommits, gitHubPat);
                globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId);
                globalTests = await getTestsForBuild(testApi, teamProject, buildId);

            } else {
                let releaseId: number = parseInt(tl.getVariable("Release.ReleaseId"));
                let releaseDefinitionId: number = parseInt(tl.getVariable("Release.DefinitionId"));
                let environmentName: string = (tl.getInput("overrideStageName") || tl.getVariable("Release_EnvironmentName")).toLowerCase();

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
                                                let baseBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId));
                                                agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
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

                                            // enrich what we have with file names
                                            if (commits) {
                                                commits = await enrichChangesWithFileDetails(gitApi, tfvcApi, commits, gitHubPat);
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
                                        globalBuilds.push(new UnifiedArtifactDetails(artifact, commits, workitems, tests));

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

            let expandedGlobalCommits = await expandTruncatedCommitMessages(vsts, globalCommits, gitHubPat);

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
            agentApi.logInfo(`Total workitems: [${globalCommits.length}]`);
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

            if (dumpPayload) {
                dumpJsonPayloadToFile(
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
                        buildDetails: currentBuild
                    });
            }

            var template = getTemplate (templateLocation, templateFile, inlineTemplate);
            var outputString = processTemplate(
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
                customHandlebarsExtensionFile,
                customHandlebarsExtensionFolder,
                prDetails,
                globalPullRequests,
                globalBuilds,
                globalTests,
                releaseTests,
                relatedWorkItems);

            writeFile(outputFile, outputString, replaceFile, appendToFile);

            agentApi.writeVariable(outputVariableName, outputString.toString());

            resolve(0);
        });
}

function dumpJsonPayloadToFile(fileName: string, payload) {
    let data = JSON.stringify(payload);
    agentApi.logInfo("Start of payload data dump");
    agentApi.logInfo(data);
    agentApi.logInfo("End of payload data dump");

    if (fileName) {
        agentApi.logInfo(`Writing payload data to file ${fileName}`);
        fs.writeFileSync(fileName, data);
    }
}