export interface SimpleArtifact {
    artifactAlias: string;
    buildDefinitionId: string;
    buildNumber: string;
    buildId: string;
    artifactType: string;
    isPrimary: boolean;
    sourceId: string;
}

interface WorkItemInfo {
    id: number;
    url: string;
}
interface EnrichedGitPullRequest extends GitPullRequest {
    associatedWorkitems: WorkItemInfo[];
    associatedCommits: GitCommit[];
}

interface EnrichedTestRun extends TestRun {
    TestResults: TestCaseResult[];
}
export class UnifiedArtifactDetails {
    build: Build;
    commits: Change[];
    workitems: WorkItem[];
    tests: TestCaseResult[];
    manualtests: EnrichedTestRun[];
    constructor ( build: Build, commits: Change[], workitems: WorkItem[], tests: TestCaseResult[], manualtests: EnrichedTestRun[]) {
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
        if (manualtests) {
            this.manualtests = manualtests;
        } else {
            this.manualtests = [];
        }
   }
}

import { ClientApiBase } from "azure-devops-node-api/ClientApiBases";
import * as vsom from "azure-devops-node-api/VsoClient";
import * as restm from "typed-rest-client/RestClient";
import path = require("path");
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
import { ResultDetails, TestCaseResult, TestResolutionState, TestRun } from "azure-devops-node-api/interfaces/TestInterfaces";
import { IWorkItemTrackingApi } from "azure-devops-node-api/WorkItemTrackingApi";
import { WorkItemExpand, WorkItem, ArtifactUriQuery, Wiql } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";
import { ITfvcApi } from "azure-devops-node-api/TfvcApi";
import * as issue349 from "./Issue349Workaround";
import { ITestApi } from "azure-devops-node-api/TestApi";
import { IBuildApi, BuildApi } from "azure-devops-node-api/BuildApi";
import * as vstsInterfaces from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import { Console, time } from "console";
import { InstalledExtensionQuery } from "azure-devops-node-api/interfaces/ExtensionManagementInterfaces";
import { SSL_OP_SSLEAY_080_CLIENT_DH_BUG } from "constants";
import { stringify } from "querystring";
import { Exception } from "handlebars";
import { IdentityDisplayFormat } from "azure-devops-node-api/interfaces/WorkInterfaces";

let agentApi = new AgentSpecificApi();

export function getDeploymentCount(environments: ReleaseEnvironment[], environmentName: string): number {
    agentApi.logInfo(`Getting deployment count for stage`);
    var attemptCount = 0;
    for (let environment of environments) {
        if (environment.name.toLowerCase() === environmentName) {
            agentApi.logInfo(`Found the stage [${environmentName}]`);
            var currentDeployment = environment.preDeployApprovals[environment.preDeployApprovals.length - 1];
            if (currentDeployment) {
                attemptCount = currentDeployment.attempt;
            }
        }
    }
    if (attemptCount === 0) {
        agentApi.logInfo(`Cannot find any deployment to [${environmentName}]`);
    } else {
        agentApi.logInfo(`Identified [${environmentName}] as having deployment count of [${attemptCount}]`);
    }
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

export async function restoreAzurePipelineArtifactsBuildInfo(artifactsInRelease: SimpleArtifact[], webApi: WebApi): Promise<number> {
    let existAzurePipelineArtifacts = false;
    for (const artifactInRelease of artifactsInRelease) {
        if (artifactInRelease.artifactType === "PackageManagement") {
            agentApi.logInfo(`The artifact [${artifactInRelease.artifactAlias}] is an Azure Artifacts, expanding build details`);
            existAzurePipelineArtifacts = true;
            // FIXME #937: workaround for missing PackagingApi library. Should replace with `const packagingApi = await organisation.getPackagingApi();` when available
            interface PackagingPackage { id: string; string; url: string; versions: {id: string; normalizedVersion: string}[]; }
            interface PackagingVersionProvenance { TeamProjectId: string; provenance: {data: {"System.DefinitionId": string; "System.TeamProjectId": string; "Build.BuildId": string; "Build.BuildNumber": string}}; }
            interface IPackagingApi {
                getPackage(project: string, feedId: string, packageId: string, includeAllVersions?: boolean): Promise<PackagingPackage>;
                getPackageVersionProvenance(project: string, feedId: string, packageId: string, packageVersionId: string): Promise<PackagingVersionProvenance>;
            }
            const PackagingApi = class extends ClientApiBase implements IPackagingApi {
                constructor(...args) { super(args[0], args[1], "node-Packaging-api", args[2]); }
                public static readonly RESOURCE_AREA_ID = "7ab4e64e-c4d8-4f50-ae73-5ef2e21642a5";
                public async getPackage(project: string, feedId: string, packageId: string, includeAllVersions?: boolean): Promise<PackagingPackage> {
                    return new Promise<PackagingPackage>(async (resolve, reject) => {
                        let routeValues: any = {project: project, feedId: feedId, packageId: packageId};
                        let queryValues: any = {includeAllVersions: includeAllVersions};
                        try {
                            let verData: vsom.ClientVersioningData = await this.vsoClient.getVersioningData("6.1-preview.1", "Packaging", "7a20d846-c929-4acc-9ea2-0d5a7df1b197", routeValues, queryValues);
                            let res = await this.rest.get<PackagingPackage[]>(verData.requestUrl!, this.createRequestOptions("application/json", verData.apiVersion));
                            resolve(this.formatResponse(res.result, null, true));
                        } catch (err) {
                            reject(err);
                        }
                    });
                }
                public async getPackageVersionProvenance(project: string, feedId: string, packageId: string, packageVersionId: string): Promise<PackagingVersionProvenance> {
                    return new Promise<PackagingVersionProvenance>(async (resolve, reject) => {
                        let routeValues: any = {
                            project: project,
                            feedId: feedId,
                            packageId: packageId,
                            packageVersionId: packageVersionId
                        };
                        try {
                            let verData: vsom.ClientVersioningData = await this.vsoClient.getVersioningData("6.1-preview.1", "Packaging", "0aaeabd4-85cd-4686-8a77-8d31c15690b8", routeValues);
                            let res = await this.rest.get<PackagingPackage[]>(verData.requestUrl!, this.createRequestOptions("application/json", verData.apiVersion));
                            resolve(this.formatResponse(res.result, null, true));
                        } catch (err) {
                            reject(err);
                        }
                    });
                }
            };
            // const packagingApi = await organisation.getPackagingApi();
            const packagingApi = await(async (serverUrl?: string, handlers?: IRequestHandler[]): Promise<IPackagingApi> => {
                const this_ = webApi as any;
                serverUrl = await this_._getResourceAreaUrl(serverUrl || this_.serverUrl, PackagingApi.RESOURCE_AREA_ID);
                handlers = handlers || [this_.authHandler];
                return new PackagingApi(serverUrl, handlers, this_.options);
            })();
            // END FIXME #937
            const guids = artifactInRelease.sourceId.match(/([0-9a-f-]{36})\/([0-9a-f-]{36})/u);
            if (guids !== null) {
                const [projectId, feedId] = [guids[1], guids[2]];
                const [packageId, packageVersion] = [artifactInRelease.buildDefinitionId, artifactInRelease.buildNumber];
                const artifactPackageInfo = await packagingApi.getPackage(projectId, feedId, packageId, true);
                const packageVersionId = (artifactPackageInfo.versions.find((version) => version.normalizedVersion === packageVersion) || {id: ""}).id;
                const artifactBuildInfo = (await packagingApi.getPackageVersionProvenance(projectId, feedId, packageId, packageVersionId));

                Object.assign(artifactInRelease, {
                    artifactType: "Build",
                    buildId: artifactBuildInfo.provenance.data["Build.BuildId"],
                    buildDefinitionId: artifactBuildInfo.provenance.data["System.DefinitionId"],
                    buildNumber: artifactBuildInfo.provenance.data["Build.BuildNumber"],
                    sourceId: artifactBuildInfo.TeamProjectId || artifactBuildInfo.provenance.data["System.TeamProjectId"]
                } as SimpleArtifact);
            }
        }
    }
    return existAzurePipelineArtifacts ? parseInt(artifactsInRelease[0].buildId) : NaN;
}

export async function getPullRequests(
    gitApi: GitApi,
    projectName: string
    ): Promise<GitPullRequest[]> {
    return new Promise<GitPullRequest[]>(async (resolve, reject) => {
        let prList: GitPullRequest[] = [];
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
            var batchSize: number = 1000; // 1000 seems to be the API max
            var skip: number = 0;
            do {
                agentApi.logDebug(`Get batch of PRs [${skip}] - [${skip + batchSize}]`);
                var prListBatch = await (gitApi.getPullRequestsByProject( projectName, filter, 0 , skip, batchSize));
                agentApi.logDebug(`Adding batch of ${prListBatch.length} PRs`);
                prList.push(...prListBatch);
                skip += batchSize;
            } while (batchSize === prListBatch.length);
            resolve(prList);
        } catch (err) {
            reject(err);
        }
    });
}

export async function getMostRecentSuccessfulDeployment(
    releaseApi: IReleaseApi,
    teamProject: string,
    releaseDefinitionId: number,
    environmentId: number,
    overrideBuildReleaseId: string,
    considerPartiallySuccessfulReleases: boolean): Promise<Deployment> {
    return new Promise<Deployment>(async (resolve, reject) => {

        let mostRecentDeployment: Deployment = null;
        try {
            // Gets the latest successful deployments - the api returns the deployments in the correct order
            agentApi.logInfo (`Finding successful deployments`);
            var successfulDeployments = await releaseApi.getDeployments(teamProject, releaseDefinitionId, environmentId, null, null, null, DeploymentStatus.Succeeded, null, true, null, null, null, null).catch((reason) => {
                reject(reason);
                return;
            });

            if (considerPartiallySuccessfulReleases === true) {
                agentApi.logInfo (`Finding partially successful deployments`);
                var partialSuccessfulDeployments = await releaseApi.getDeployments(teamProject, releaseDefinitionId, environmentId, null, null, null, DeploymentStatus.PartiallySucceeded, null, true, null, null, null, null).catch((reason) => {
                    reject(reason);
                    return;
                });

                // merge the arrays
                if (successfulDeployments && successfulDeployments.length > 0) {
                    if (partialSuccessfulDeployments && partialSuccessfulDeployments.length > 0) {
                        agentApi.logInfo (`Merging and sorting successful and partially successful deployments`);
                        successfulDeployments.push(...partialSuccessfulDeployments);
                        successfulDeployments.sort((a, b) => { if (a && b) { return b.id - a.id; } return 0; });
                    } else {
                        agentApi.logInfo (`No partially successful deployments to consider only using successful deployments`);
                    }
                } else {
                    agentApi.logInfo (`No successful deployments using partially successful deployments`);
                    successfulDeployments = partialSuccessfulDeployments;
                }

            }

            if (successfulDeployments && successfulDeployments.length > 0) {
                agentApi.logInfo (`Found ${successfulDeployments.length} releases to consider`);
                successfulDeployments.forEach(deployment => {
                    agentApi.logDebug (`Found ReleaseID ${deployment.id} with the Status ${deployment.deploymentStatus}`);
                });

                if (overrideBuildReleaseId && !isNaN(parseInt(overrideBuildReleaseId))) {
                    agentApi.logInfo (`Trying to find successful deployment with the override release ID of '${overrideBuildReleaseId}'`);
                    mostRecentDeployment = successfulDeployments.find (element => element.release.id === parseInt(overrideBuildReleaseId));
                    if (mostRecentDeployment) {
                        agentApi.logInfo (`Found matching override release ${mostRecentDeployment.release.name}`);
                    } else {
                        agentApi.logError (`Cannot find matching release`);
                        reject(-1);
                        return;
                    }
                } else {
                    mostRecentDeployment = successfulDeployments[0];
                    agentApi.logInfo (`Finding the last successful release ${mostRecentDeployment.release.name}`);
                }
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
            agentApi.logInfo(`Expanded truncated commit messages ${expanded}`);
            resolve(globalCommits);
    });
}

export async function enrichPullRequest(
    gitApi: IGitApi,
    pullRequests: EnrichedGitPullRequest[]
): Promise<EnrichedGitPullRequest[]> {
    return new Promise<EnrichedGitPullRequest[]>(async (resolve, reject) => {
        try {
            for (let prIndex = 0; prIndex < pullRequests.length; prIndex++) {
                const prDetails = pullRequests[prIndex];
                // get any missing labels for all the known PRs we are interested in as getPullRequestById does not populate labels, so get those as well
                if (!prDetails.labels || prDetails.labels.length === 0 ) {
                    agentApi.logDebug(`Checking for tags for ${prDetails.pullRequestId}`);
                    const prLabels = await (gitApi.getPullRequestLabels(prDetails.repository.id, prDetails.pullRequestId));
                    prDetails.labels = prLabels;
                }
                // and added the WI IDs
                var wiRefs = await (gitApi.getPullRequestWorkItemRefs(prDetails.repository.id, prDetails.pullRequestId));
                prDetails.associatedWorkitems = wiRefs.map(wi => {
                    return {
                        id: parseInt(wi.id),
                        url: wi.url
                    };
                }) ;
                agentApi.logDebug(`Added ${prDetails.associatedWorkitems.length} work items for ${prDetails.pullRequestId}`);

                prDetails.associatedCommits = [];
                var csRefs = await (gitApi.getPullRequestCommits(prDetails.repository.id, prDetails.pullRequestId));
                for (let csIndex = 0; csIndex < csRefs.length; csIndex++) {
                    prDetails.associatedCommits.push ( await (gitApi.getCommit(csRefs[csIndex].commitId, prDetails.repository.id)));
                }
                agentApi.logDebug(`Added ${prDetails.associatedCommits.length} commits for ${prDetails.pullRequestId}, note this includes commits on the PR source branch not associated directly with the build`);

            }
            resolve(pullRequests);
        } catch (err) {
            reject(err);
        }
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
            if (changes && changes.length > 0) {
                for (let index = 0; index < changes.length; index++) {
                    const change = changes[index];
                    try {
                        agentApi.logInfo (`Enriched change ${change.id} of type ${change.type}`);
                        if (change.type === "TfsGit") {
                            // we need the repository ID for the API call
                            // the alternative is to take the basic location value and build a rest call from that
                            // neither are that nice.
                            var url = require("url");
                            // split the url up, check it is the expected format and then get the ID
                            var urlParts = url.parse(change.location);
                            try {
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
                            } catch (ex)  {
                                agentApi.logInfo (`Cannot enriched ${ex}`);
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
            } else {
               changes = [];
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
        agentApi.logDebug("Getting System.AccessToken");
        var accessToken = agentApi.getSystemAccessToken();
        let credHandler: IRequestHandler;
        if (!accessToken || accessToken.length === 0) {
            throw "Unable to locate access token that will allow access to Azure DevOps API.";
        } else {
            agentApi.logInfo("Creating the credential handler from the OAUTH token");
            // used for local debugging.  Allows switching between PAT token and Bearer Token for debugging
            credHandler = webApi.getHandlerFromToken(accessToken, true);
        }
        return credHandler;
    } else {
        agentApi.logInfo("Creating the credential handler using override PAT (suitable for local testing or if the OAUTH token cannot be used)");
        return webApi.getPersonalAccessTokenHandler(pat, true);
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
            let buildTestResults = await (testAPI.getTestResultsByBuild(teamProject, buildId));
            tl.debug(`Found ${buildTestResults.length} automated test results associated with the build`);
            if ( buildTestResults.length > 0 ) {
                for (let index = 0; index < buildTestResults.length; index++) {
                    const test = buildTestResults[index];
                    if (testList.filter(e => e.testRun.id === `${test.runId}`).length === 0) {
                        var skip = 0;
                        var batchSize = 1000; // the API max is 1000
                        do {
                            agentApi.logDebug(`Get batch of automated tests [${skip}] - [${skip + batchSize}] for test run ${test.runId}`);
                            var runBatch = await (testAPI.getTestResults(teamProject, test.runId, null, skip, batchSize));
                            tl.debug(`Adding ${runBatch.length} tests`);
                            testList.push(...runBatch);
                            skip += batchSize;
                        } while (batchSize === runBatch.length);
                    } else {
                       tl.debug(`Skipping adding tests for test run ${test.runId} as already added`);
                    }
                }
                tl.debug(`Test results expanded to unique ${testList.length} test results`);
            } else {
                tl.debug(`No automated tests associated with build ${buildId}`);
            }
            resolve(testList);
        } catch (err) {
            reject(err);
        }
    });
}

export async function getManualTestsForBuild(
    restClient: restm.RestClient,
    testAPI: TestApi,
    tpcUri: string,
    teamProject: string,
    buildid: number,
    globalManualTestConfigurations
): Promise<EnrichedTestRun[]> {
    return new Promise<EnrichedTestRun[]>(async (resolve, reject) => {
        let testRunList: EnrichedTestRun[] = [];
        try {
            let buildTestRuns = [];
            var runSkip = 0;
            var batchSize = 1000; // the API max
            let usedConfigurations = [];
            do {
                agentApi.logDebug(`Get batch of manual test runs [${runSkip}] - [${runSkip + batchSize}]`);
                var runs = await (testAPI.getTestRuns(
                    teamProject,
                    `vstfs:///Build/Build/${buildid}`,
                    null, // owner
                    null, // tmpiRunId
                    null, // planId
                    true, // include details
                    false, // shows both manual and automated
                    runSkip,
                    batchSize));
                // this returns both manual and automated we need to filter
                runs = runs.filter(run => run.isAutomated === false);
                buildTestRuns.push(...runs);
            } while (batchSize === runs.length);
            tl.debug(`Found ${buildTestRuns.length} manual test runs associated with the build`);

            if ( buildTestRuns.length > 0 ) {
                for (let index = 0; index < buildTestRuns.length; index++) {
                    const testRun = <EnrichedTestRun>buildTestRuns[index];
                    testRun.TestResults = [];
                    var resultSkip = 0;
                    do {
                        agentApi.logDebug(`Get batch of tests [${resultSkip}] - [${resultSkip + batchSize}] for test run ${testRun.id}`);
                        // get the test steps
                        var batch = await testAPI.getTestResults(teamProject, testRun.id, ResultDetails.Point, resultSkip, batchSize );
                        testRun.TestResults.push (...batch);
                        // get the list of unique configurations
                        var uniqueIDs = [...new Set(batch.map(item => item.configuration.id))];
                        uniqueIDs.forEach(id => {
                            if (!usedConfigurations.includes(id)) {
                                usedConfigurations.push(id);
                            }
                        });
                    } while (batchSize === batch.length);
                    testRunList.push(testRun);
                    tl.debug(`Manual Test Run ${testRun.id} enriched with ${testRun.TestResults.length} individual test results`);
                }

                // get the details of the test configurations. There is no SDK call for this, so making a base REST call
                try {
                    // extract a URL to use with the client
                    for (let index = 0; index < usedConfigurations.length; index++) {
                        tl.debug(`Getting details of the test configuration ${usedConfigurations[index]}`);
                        let response = await restClient.get(`${tpcUri}/${teamProject}/_apis/test/configurations/${usedConfigurations[index]}?api-version=5.0-preview.2`);
                        globalManualTestConfigurations.push(response.result);
                    }
                } catch (err) {
                    tl.warning(`Cannot get the details of the test configuration`);
                }

            } else {
                tl.debug(`No manual test plans associated with build`);
            }
            resolve(testRunList);
        } catch (err) {
            reject(err);
        }
    });
}

export async function getConsumedArtifactsForBuild(
    restClient: restm.RestClient,
    tpcUri: string,
    teamProject: string,
    buildid: number
): Promise<[]> {
    return new Promise<[]>(async (resolve, reject) => {
        let consumedArtifacts: [] = [];
        try {
            var payload = {
                "contributionIds": [
                    "ms.vss-build-web.run-consumed-artifacts-data-provider"
                ],
                "dataProviderContext": {
                    "properties": {
                        "buildId": `${buildid}`,
                        "sourcePage": {
                            "url": `${tpcUri}/${teamProject}/_build/results?buildId=${buildid}&view=results`,
                            "routeId": "ms.vss-build-web.ci-results-hub-route",
                            "routeValues": {
                                "project": `${teamProject}`,
                                "viewname": "build-results",
                                "controller": "ContributedPage",
                                "action": "Execute"
                            }
                        }
                    }
                }
            };
            let response = await restClient.create(
                `${tpcUri}/_apis/Contribution/HierarchyQuery/project/${teamProject}?api-version=5.1-preview`,
                payload);
            var result = response.result;
            resolve(response.result["dataProviders"]["ms.vss-build-web.run-consumed-artifacts-data-provider"].consumedSources);
        } catch (err) {
            tl.warning(`Cannot get the details of the consumed artifacts ${err}`);
            resolve([]);
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
                    let envTestResults = await (testAPI.getTestResultDetailsForRelease(teamProject, release.id, env.id));
                    if (envTestResults.resultsForGroup.length > 0) {
                        for (let index = 0; index < envTestResults.resultsForGroup[0].results.length; index++) {
                            const test =  envTestResults.resultsForGroup[0].results[index];
                            if (testList.filter(e => e.testRun.id === `${test.testRun.id}`).length === 0) {
                                tl.debug(`Adding tests for test run ${test.testRun.id}`);
                                let run = await (testAPI.getTestResults(teamProject, parseInt(test.testRun.id)));
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
        templateFile: string ,
        inlinetemplate: string
    ): Array<string> {
        agentApi.logDebug(`Using template mode ${templateLocation}`);
        var template;
        const handlebarIndicator = "{{";

        if (templateLocation === "File") {
            if (fs.existsSync(templateFile)) {
                agentApi.logInfo (`Loading template file ${templateFile}`);
                template = fs.readFileSync(templateFile, "utf8").toString();
            } else {
                agentApi.logError (`Cannot find template file ${templateFile}`);
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
                    relatedWorkItems.push(await (workItemTrackingApi.getWorkItem(id, null, null, WorkItemExpand.All, null)));
                } else {
                    agentApi.logInfo(`Skipping ${id} as already in the relations list`);
                }
            }
        }
    }

    return relatedWorkItems;

}

export async function getAllParentWorkitems (
    workItemTrackingApi: IWorkItemTrackingApi,
    relatedWorkItems: WorkItem[]
) {
    var allRelatedWorkItems = [...relatedWorkItems]; // a clone
    var knownWI = allRelatedWorkItems.length;
    var addedOnThisPass = 0;
    do {
        // reset the count
        addedOnThisPass = 0;
        // look for all the parent
        for (let wiIndex = 0; wiIndex < allRelatedWorkItems.length; wiIndex++) {
            var wi  = allRelatedWorkItems[wiIndex];

            agentApi.logInfo(`Looking for parents of WI [${wi.id}]`);
            for (let relIndex = 0; relIndex <  wi.relations.length; relIndex++) {
                var relation  =  wi.relations[relIndex];
                if (relation.attributes.name === "Parent") {
                    var urlParts = relation.url.split("/");
                    var id = parseInt(urlParts[urlParts.length - 1]);
                    if (!allRelatedWorkItems.find(element => element.id === id)) {
                        agentApi.logInfo(`Add ${relation.attributes.name} WI ${id}`);
                        allRelatedWorkItems.push(await (workItemTrackingApi.getWorkItem(id, null, null, WorkItemExpand.All, null)));
                        // if we add something add to the count
                        addedOnThisPass ++;
                    } else {
                        agentApi.logInfo(`Skipping ${id} as already in the found parent list`);
                    }
                }
            }
        }
    } while (addedOnThisPass !== 0); // exit if we added nothing in this pass

    agentApi.logInfo(`Added ${allRelatedWorkItems.length - knownWI} parent WI to the list of direct relations`);
    return allRelatedWorkItems;

}

export async function getFullWorkItemDetails (
    workItemTrackingApi: IWorkItemTrackingApi,
    workItemRefs: ResourceRef[]
) {
    let fullWorkItems: WorkItem[] = [];
    if (workItemRefs && workItemRefs.length > 0) {
        var workItemIds = workItemRefs.map(wi => parseInt(wi.id));
        agentApi.logInfo(`Get details of [${workItemIds.length}] WIs`);
        if (workItemIds && workItemIds.length > 0) {
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
    pullRequests: EnrichedGitPullRequest[],
    globalBuilds: UnifiedArtifactDetails[],
    globalTests: TestCaseResult[],
    releaseTests: TestCaseResult[],
    relatedWorkItems: WorkItem[],
    compareBuildDetails: Build,
    currentStage: TimelineRecord,
    inDirectlyAssociatedPullRequests: EnrichedGitPullRequest[],
    globalManualTests: EnrichedTestRun[],
    globalManualTestConfigurations: [],
    stopOnError: boolean,
    globalConsumedArtifacts: any[],
    queryWorkItems: WorkItem[]
    ): string {

    var output = "";

    if (template.length > 0) {
        agentApi.logDebug("Processing template");
        agentApi.logDebug(`  WI: ${workItems.length}`);
        agentApi.logDebug(`  CS: ${commits.length}`);
        agentApi.logDebug(`  PR: ${pullRequests.length}`);
        agentApi.logDebug(`  Builds: ${globalBuilds.length}`);
        agentApi.logDebug(`  Manual Tests: ${globalManualTests.length}`);
        agentApi.logDebug(`  Manual TestConfigurations: ${globalManualTestConfigurations.length}`);
        agentApi.logDebug(`  Release Tests: ${releaseTests.length}`);
        agentApi.logDebug(`  Related WI: ${relatedWorkItems.length}`);
        agentApi.logDebug(`  Indirect PR: ${inDirectlyAssociatedPullRequests.length}`);
        agentApi.logDebug(`  Consumed Artifacts: ${globalConsumedArtifacts.length}`);
        agentApi.logDebug(`  Query WI: ${queryWorkItems.length}`);

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
            var wiId = parseInt(urlParts[urlParts.length - 1]);
            return array.find(element => element.id === wiId);
        });

        // add our helper to find test configuration
        handlebars.registerHelper("lookup_a_test_configuration", function (array, id) {
            return array.find(element => element.id === Number(id));
        });

        // add our helper to find PR
        handlebars.registerHelper("lookup_a_pullrequest", function (array, url) {
            var urlParts = url.split("%2F");
            var prId = parseInt(urlParts[urlParts.length - 1]);
            return array.find(element => element.pullRequestId === prId);
        });

        // add our helper to get first line of commit message
        handlebars.registerHelper("get_only_message_firstline", function (msg) {
            return msg.split(`\n`)[0];
        });

        // add our helper to find PR
        handlebars.registerHelper("lookup_a_pullrequest_by_merge_commit", function (array, commitId) {
            return array.find(element => element.lastMergeCommit.commitId === commitId);
        });

        // make sure we have valid file name for the custom extension
        if (! customHandlebarsExtensionFile || customHandlebarsExtensionFile.length === 0) {
            customHandlebarsExtensionFile = "customHandlebarsExtension.js";
        } else {
            if (!customHandlebarsExtensionFile.toLowerCase().endsWith(".js")) {
                customHandlebarsExtensionFile = customHandlebarsExtensionFile + ".js";
            }
        }

        if (!customHandlebarsExtensionFolder || customHandlebarsExtensionFolder.length === 0) {
            // cannot use process.env.Agent_TempDirectory as only set on Windows agent, so build it up from the agent base
            // Note that the name is case sensitive on Mac and Linux
            // Also #832 found that the temp file has to be under the same folder structure as the main .js files
            // else you cannot load any modules
            customHandlebarsExtensionFolder = __dirname;
        } else {
            // check if a relative path is used and prepend the current directory. If not done the load fails
            if (!path.isAbsolute(customHandlebarsExtensionFolder)) {
                agentApi.logDebug(`An absolute path has not been provided for the customHandlebarsExtensionFolder, pre-pending the current working directory`);
                customHandlebarsExtensionFolder = path.join(__dirname, customHandlebarsExtensionFolder);
            }
        }

        var filePath = path.join(customHandlebarsExtensionFolder, customHandlebarsExtensionFile);

        if (typeof customHandlebarsExtensionCode !== undefined && customHandlebarsExtensionCode && customHandlebarsExtensionCode.length > 0) {
            agentApi.logDebug(`Saving custom Handlebars code passed as a string in the parameter 'customHandlebarsExtensionCode' to file ${filePath}`);
            writeFile(filePath, customHandlebarsExtensionCode, true, false);
        }

        agentApi.logDebug(`Attempting to load custom handlebars extension from ${filePath}}`);
        if (fs.existsSync(filePath)) {
            var customModule = fs.readFileSync(filePath);
            if (customModule.toString().trim().length > 0) {
                var tools = require(filePath);
                handlebars.registerHelper(tools);
                agentApi.logInfo("Loaded handlebars extension file");
            } else {
                agentApi.logDebug("Custom handlebars extension file is empty");
            }
        } else {
            agentApi.logDebug("Custom handlebars extension file does not exist");
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
                "compareBuildDetails": compareBuildDetails,
                "inDirectlyAssociatedPullRequests": inDirectlyAssociatedPullRequests,
                "manualTests": globalManualTests,
                "manualTestConfigurations": globalManualTestConfigurations,
                "consumedArtifacts": globalConsumedArtifacts,
                "currentStage": currentStage,
                "queryWorkItems": queryWorkItems
            });
            agentApi.logInfo( "Completed processing template");

        } catch (err) {
            if (stopOnError) {
                throw (`Error Processing handlebars [${err}]`);
            } else {
                agentApi.logError(`Error Processing handlebars [${err}]`);
                agentApi.logWarn(`As the parameter 'stopOnError' is set to false the above Handlebars processing error has been logged but the task not marked as failed. To fail the task when this occurs, change the parameter to true`);
            }
        }
    } else {
        if (stopOnError) {
            throw (`Cannot load template file [${template}] or it is empty`);
        } else {
            agentApi.logError( `Cannot load template file [${template}] or it is empty`);
            agentApi.logWarn(`As the parameter 'stopOnError' is set to false the above Handlebars processing error has been logged but the task not marked as failed. To fail the task when this occurs, change the parameter to true`);
        }

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
    buildDefId: number,
    tags: string[],
    overrideBuildReleaseId: string,
    considerPartiallySuccessfulReleases: boolean
)  {
    if (stageName.length === 0) {
        agentApi.logInfo ("No stage name provided, cannot find last successful build by stage");
        return {
            id: 0,
            stage: null
        };
    }

    // #1095
    // there is a default of 1000 builds per definition returned returned by the API
    // but the continuation token is not supported, so we cannot get the next batch
    // we could all the API using the raw REST call, but building the url will be a bit more complex
    // so now just force the top value to it's max of 5000
    // this has no effect when there are fewer than 5000 builds in the definition

    let builds = await buildApi.getBuilds(teamProject, [buildDefId],
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        5000,
        undefined,
        undefined,
        undefined,
        6 // startTimeDescending
    );

    if (builds.length > 1 ) {
        agentApi.logInfo(`Found '${builds.length}' matching builds to consider`);
        if (considerPartiallySuccessfulReleases) {
            agentApi.logInfo(`Matching 'successful' or 'partially successful' builds`);
        } else {
            agentApi.logInfo(`Matching 'successful' builds only `);
        }
        // check of we are using an override
        if (overrideBuildReleaseId && overrideBuildReleaseId.length > 0) {
            agentApi.logInfo(`An override build number has been passed, will only consider this build`);
            var overrideBuild = builds.find(element => element.id.toString() === overrideBuildReleaseId);
            if (overrideBuild) {
                agentApi.logInfo(`Found the over ride build ${overrideBuildReleaseId}`);
                // we need to find the required timeline record
                let timeline = await (buildApi.getBuildTimeline(teamProject, overrideBuild.id));
                let record = timeline.records.find(element => element.name === stageName);
                return {
                    id: overrideBuild.id,
                    stage: record
                };
            } else {
               agentApi.logError(`There is no build matching the override ID of ${overrideBuildReleaseId}`);
               return;
            }
        }

        builds.sort((a, b) => <any>b.queueTime - <any>a.queueTime);

        let foundSelf = false;

        for (let buildIndex = 0; buildIndex < builds.length; buildIndex++) {
            const build = builds[buildIndex];
            agentApi.logInfo (`Comparing ${build.id} against ${buildId}`);
            // force the cast to string as was getting a type mimatch
            if (build.id.toString() === buildId.toString()) {
                agentApi.logInfo("Ignore compare against self");
                foundSelf = true;
            } else if (!foundSelf) {
                agentApi.logInfo(`Ignoring ${build.id} (${build.buildNumber}) since not yet reached the current build`);
            } else {
                if (tags.length === 0 ||
                    (tags.length > 0 && build.tags.sort().join(",") === tags.sort().join(","))) {
                        agentApi.logInfo("Considering build");
                        let timeline = await (buildApi.getBuildTimeline(teamProject, build.id));
                        if (timeline && timeline.records) {
                            for (let timelineIndex = 0; timelineIndex < timeline.records.length; timelineIndex++) {
                                const record  = timeline.records[timelineIndex];
                                if (record.type === "Stage") {
                                    if (record.name === stageName || record.identifier === stageName) {
                                        agentApi.logInfo (`Found required stage ${record.name} in the state ${record.state.toString()} with the result ${record.result?.toString()} state for build ${build.id}`);
                                        // checking enum values against
                                        // https://docs.microsoft.com/en-us/dotnet/api/microsoft.teamfoundation.distributedtask.webapi.timelinerecordstate?view=azure-devops-dotnet
                                        // https://docs.microsoft.com/en-us/dotnet/api/microsoft.teamfoundation.distributedtask.webapi.taskresult?view=azure-devops-dotnet
                                        if ((record.state.toString() === "2" || record.state.toString() === "completed") && // completed
                                        (
                                            (considerPartiallySuccessfulReleases === false && (record.result.toString() === "0" || record.result.toString().toLowerCase() === "succeeded")) ||
                                            (considerPartiallySuccessfulReleases === true && (record.result.toString() === "1" || record.result.toString().toLowerCase() === "succeededwithissues" || record.result.toString() === "0" || record.result.toString() === "succeeded"))
                                        )) {
                                            agentApi.logInfo (`Using the build ${build.id}`);
                                            return {
                                                id: build.id,
                                                stage: record
                                            };
                                        }
                                    }
                                }
                            }
                    } else {
                        agentApi.logInfo("Skipping check as no timeline available for this build");
                    }
                    } else {
                        agentApi.logInfo(`Skipping build as does not have the correct tags`);
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
    checkStage: boolean,
    getAllParents: boolean,
    tags: string,
    overrideBuildReleaseId: string,
    getIndirectPullRequests: boolean,
    maxRetries: number,
    stopOnError: boolean,
    considerPartiallySuccessfulReleases: boolean,
    sortCS: boolean,
    checkForManuallyLinkedWI: boolean,
    wiqlWhereClause: string
    ): Promise<number> {
        return new Promise<number>(async (resolve, reject) => {

            // check if we have multiple templates to process
            var templateFiles = templateFile.split(",").map(function(item) {
                return item.trim();
              });
            var outputFiles = outputFile.split(",").map(function(item) {
                return item.trim();
            });

            if (templateFiles.length !== outputFiles.length) {
                reject("The number of template files and output files must be the same");
                return;
            }

            if (!gitHubPat) {
                // a check to make sure we don't get a null
                gitHubPat = "";
            }

            agentApi.logInfo(`Creating Azure DevOps API connections for ${tpcUri} with 'allowRetries' set to '${maxRetries > 0}' and 'maxRetries' count to '${maxRetries}'`);
            const credentialHandler = getCredentialHandler(pat);
            const options = {
                allowRetries: maxRetries > 0 ,
                maxRetries: maxRetries,
            } as vstsInterfaces.IRequestOptions;
            const organisationWebApi = new webApi.WebApi(tpcUri, credentialHandler, options);
            const releaseApi = await organisationWebApi.getReleaseApi();
            const buildApi = await organisationWebApi.getBuildApi();
            const gitApi = await organisationWebApi.getGitApi();
            const testApi = await organisationWebApi.getTestApi();
            const workItemTrackingApi = await organisationWebApi.getWorkItemTrackingApi();
            const tfvcApi = await organisationWebApi.getTfvcApi();

            // the result containers
            var globalCommits: Change[] = [];
            var globalWorkItems: ResourceRef[] = [];
            var globalPullRequests: EnrichedGitPullRequest[] = [];
            var inDirectlyAssociatedPullRequests: EnrichedGitPullRequest[] = [];
            var globalBuilds: UnifiedArtifactDetails[] = [];
            var globalTests: TestCaseResult[] = [];
            var releaseTests: TestCaseResult[] = [];
            var relatedWorkItems: WorkItem[] = [];
            var fullWorkItems: WorkItem[] = [];
            var queryWorkItems: WorkItem[] = [];
            var globalManualTests: EnrichedTestRun[] = [];
            var globalManualTestConfigurations: [] = [];
            var globalConsumedArtifacts: any[] = [];

            var mostRecentSuccessfulDeploymentName: string = "";
            var mostRecentSuccessfulDeploymentRelease: Release;
            var mostRecentSuccessfulBuild: Build;

            var currentRelease: Release;
            var currentBuild: Build;
            var currentStage: TimelineRecord;
            var hasBeenTimeout = false;

            try {

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
                    var tagArray = [];

                    if (tags && tags.length > 0 ) {
                        tagArray = tags.split(",");
                        agentApi.logInfo(`Only considering builds with the tag(s) '${tags}'`);
                    }
                    if (overrideStageName && overrideStageName.length > 0) {
                        agentApi.logInfo(`Overriding current stage '${stageName}' with '${overrideStageName}'`);
                        stageName = overrideStageName;
                    }

                    var lastGoodBuildId;
                    if (overrideBuildReleaseId && overrideBuildReleaseId.length > 0 ) {
                        if (isNaN(parseInt(overrideBuildReleaseId, 10))) {
                            agentApi.logError(`The override build ID '${overrideBuildReleaseId}' is not a number `);
                            resolve(-1);
                            return;
                        }
                        agentApi.logInfo (`Using the override for the last successful build of ID '${overrideBuildReleaseId}'`);
                    }

                    agentApi.logInfo (`Getting items associated the builds since the last successful build to the stage '${stageName}'`);
                    var successfulStageDetails = await getLastSuccessfulBuildByStage(
                        buildApi,
                        teamProject,
                        stageName,
                        buildId,
                        currentBuild.definition.id,
                        tagArray,
                        overrideBuildReleaseId,
                        considerPartiallySuccessfulReleases);
                    lastGoodBuildId = successfulStageDetails.id;

                    if (lastGoodBuildId !== 0) {
                        agentApi.logInfo(`Getting the details between ${lastGoodBuildId} and ${buildId}`);
                        currentStage = successfulStageDetails.stage;

                        mostRecentSuccessfulBuild = await buildApi.getBuild(teamProject, lastGoodBuildId);

                        // There is only a workaround for Git but not for TFVC :(
                        if (mostRecentSuccessfulBuild.repository.type === "TfsGit") {
                            agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                            let currentBuild = await buildApi.getBuild(teamProject, buildId);
                            let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(organisationWebApi, mostRecentSuccessfulBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
                            globalCommits = commitInfo.commits;
                            globalWorkItems = commitInfo.workItems;
                        } else {
                            // Fall back to original behavior
                            globalCommits = await buildApi.getChangesBetweenBuilds(teamProject, lastGoodBuildId, buildId);
                            globalWorkItems = await buildApi.getWorkItemsBetweenBuilds(teamProject, lastGoodBuildId, buildId);
                        }

                        if (checkForManuallyLinkedWI) {
                            globalWorkItems = globalWorkItems.concat(await addMissingManuallyLinkedWI(buildApi, teamProject, currentBuild.definition.id, lastGoodBuildId, buildId));
                        }

                        // get the consumed artifacts for the current build
                        var currentBuildArtifacts = await getConsumedArtifactsForBuild(
                            organisationWebApi.rest,
                            tpcUri,
                            teamProject,
                            buildId);

                        var lastGoodBuildArtifacts = await getConsumedArtifactsForBuild(
                            organisationWebApi.rest,
                            tpcUri,
                            teamProject,
                            lastGoodBuildId);

                        // we can't use the standard enrichConsumedArtifacts because we need to get the artifacts from the last good build
                        for (let artifactIndex = 0; artifactIndex < currentBuildArtifacts.length; artifactIndex++) {
                            const currentBuildArtifact = currentBuildArtifacts[artifactIndex];

                            if (currentBuildArtifact["artifactCategory"] === "Pipeline") {

                                // need to find the matching artifact in the past release
                                const lastGoodBuildArtifact = lastGoodBuildArtifacts.find(artifactInLastGoodBuild => (artifactInLastGoodBuild as any).alias === (currentBuildArtifact as any).alias);

                                if (lastGoodBuildArtifact) {
                                    agentApi.logInfo(`Getting changes for the '${(currentBuildArtifact as any).artifactCategory}' artifact '${(currentBuildArtifact as any).alias}' between ${(lastGoodBuildArtifact as any).versionId} and ${(currentBuildArtifact as any).versionId}`);

                                    var wi = await buildApi.getWorkItemsBetweenBuilds((currentBuildArtifact as any).properties.projectId, (lastGoodBuildArtifact as any).versionId, (currentBuildArtifact as any).versionId);

                                    if (checkForManuallyLinkedWI) {
                                        wi = wi.concat(await addMissingManuallyLinkedWI(
                                            buildApi,
                                            (currentBuildArtifact as any).properties.projectId,
                                            (lastGoodBuildArtifact as any).definitionId,
                                            (lastGoodBuildArtifact as any).versionId,
                                            (currentBuildArtifact as any).versionId));
                                     }

                                    globalConsumedArtifacts.push({
                                        "artifactCategory": (currentBuildArtifact as any).artifactCategory,
                                        "artifactType": (currentBuildArtifact as any).artifactType,
                                        "alias": (currentBuildArtifact as any).alias,
                                        "properties": {
                                            "projectId": (currentBuildArtifact as any).properties.projectId
                                        },
                                        "versionName": `${(lastGoodBuildArtifact as any).versionName} - ${(currentBuildArtifact as any).versionName}`,
                                        "commits":	await enrichChangesWithFileDetails(
                                            gitApi,
                                            tfvcApi,
                                            await buildApi.getChangesBetweenBuilds((currentBuildArtifact as any).properties.projectId, (lastGoodBuildArtifact as any).versionId, (currentBuildArtifact as any).versionId),
                                            gitHubPat),
                                        "workitems": await getFullWorkItemDetails(workItemTrackingApi, wi)
                                    });
                                } else {
                                    agentApi.logInfo(`Cannot find a matching '${(currentBuildArtifact as any).artifactCategory}' artifact for '${(currentBuildArtifact as any).alias}' in the build ${lastGoodBuildId}, so just getting directly associated commits and wi wit the build`);
                                    globalConsumedArtifacts.push({
                                        "artifactCategory": (currentBuildArtifact as any).artifactCategory,
                                        "artifactType": (currentBuildArtifact as any).artifactType,
                                        "alias": (currentBuildArtifact as any).alias,
                                        "properties": {
                                            "projectId": (currentBuildArtifact as any).properties.projectId
                                        },
                                        "versionName": (currentBuildArtifact as any).versionName,
                                        "commits":	await enrichChangesWithFileDetails(
                                            gitApi,
                                            tfvcApi,
                                            await (buildApi.getBuildChanges((currentBuildArtifact as any).properties.projectId, (currentBuildArtifact as any).versionId, "", 5000)),
                                            gitHubPat),
                                        "workitems": await getFullWorkItemDetails(
                                            workItemTrackingApi,
                                            await (buildApi.getBuildWorkItemsRefs((currentBuildArtifact as any).properties.projectId, (currentBuildArtifact as any).versionId, 5000)))
                                    });

                                }
                            } else {
                                agentApi.logInfo(`Cannot get extra commit and work item details of the '${currentBuildArtifact["artifactCategory"]}' artifact '${currentBuildArtifact["alias"]}', so just adding base information`);
                                globalConsumedArtifacts.push({
                                    "artifactCategory": (currentBuildArtifact as any).artifactCategory,
                                    "artifactType": (currentBuildArtifact as any).artifactType,
                                    "alias": (currentBuildArtifact as any).alias,
                                    "properties": {
                                        "projectId": (currentBuildArtifact as any).properties.projectId
                                    },
                                    "commits": [],
                                    "workitems": []
                                });
                            }

                        }

                    } else {
                        agentApi.logInfo("There has been no past successful build for this stage, we need to get the details for all past builds");

                        // We need to get the details of the first build then all all the subseq
                        // #1095
                        // there is a default of 1000 builds per definition returned returned by the API
                        // but the continuation token is not supported, so we cannot get the next batch
                        // we could all the API using the raw REST call, but building the url will be a bit more complex
                        // so now just force the top value to it's max of 5000
                        // this has no effect when there are fewer than 5000 builds in the definition
                        let builds = await buildApi.getBuilds(teamProject, [currentBuild.definition.id],
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            undefined,
                            5000,
                            undefined,
                            undefined,
                            undefined,
                            6 // startTimeDescending
                        );

                        agentApi.logDebug(`Found ${builds.length} builds of this definition`);
                        if (builds.length > 2 ) {
                          var firstBuild = builds[builds.length - 1 ];
                          agentApi.logDebug(`Getting the details of the first build ${firstBuild.id}`);
                          globalCommits = await buildApi.getBuildChanges(teamProject, firstBuild.id, "", 5000);
                          globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, firstBuild.id, 5000);

                          agentApi.logDebug(`Getting the details of the changes between the first build ${firstBuild.id} and the current build ${currentBuild.id}`);
                          // There is only a workaround for Git but not for TFVC :(
                          if (firstBuild.repository.type === "TfsGit") {
                            agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                            let currentBuild = await buildApi.getBuild(teamProject, buildId);
                            let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(organisationWebApi, firstBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
                            globalCommits.push (... commitInfo.commits);
                            globalWorkItems.push (... commitInfo.workItems);

                        } else {
                            // Fall back to original behavior
                            globalCommits.push (... await buildApi.getChangesBetweenBuilds(teamProject, firstBuild.id, buildId));
                            globalWorkItems.push (... await buildApi.getWorkItemsBetweenBuilds(teamProject, firstBuild.id, buildId));
                        }

                        if (checkForManuallyLinkedWI) {
                            globalWorkItems = globalWorkItems.concat(await addMissingManuallyLinkedWI(buildApi, teamProject,  firstBuild.definition.id, firstBuild.id, buildId));
                        }

                        } else {
                          agentApi.logInfo("There have been no past builds for this definition just getting details of the current build");

                          globalCommits = await buildApi.getBuildChanges(teamProject, buildId, "", 5000);
                          globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId, 5000); // this includes the manual links check by default
                        }

                        agentApi.logInfo("Get the artifacts consumed by the build");
                        globalConsumedArtifacts = await getConsumedArtifactsForBuild(
                            organisationWebApi.rest,
                            tpcUri,
                            teamProject,
                            buildId);

                        globalConsumedArtifacts = await enrichConsumedArtifacts(
                            globalConsumedArtifacts,
                            buildApi,
                            workItemTrackingApi);

                    }
                } else {
                    agentApi.logInfo (`Getting items associated with only the current build`);
                    globalCommits = await buildApi.getBuildChanges(teamProject, buildId, "", 5000);
                    globalWorkItems = await buildApi.getBuildWorkItemsRefs(teamProject, buildId, 5000);

                    agentApi.logInfo("Get the artifacts consumed by the build");
                    globalConsumedArtifacts = await getConsumedArtifactsForBuild(
                        organisationWebApi.rest,
                        tpcUri,
                        teamProject,
                        buildId);

                    globalConsumedArtifacts = await enrichConsumedArtifacts(
                        globalConsumedArtifacts,
                        buildApi,
                        workItemTrackingApi);

                }
                agentApi.logInfo("Get the file details associated with the commits");
                globalCommits = await enrichChangesWithFileDetails(gitApi, tfvcApi, globalCommits, gitHubPat);
                agentApi.logInfo("Get any test details associated with the build");
                globalTests = await getTestsForBuild(testApi, teamProject, buildId);
                agentApi.logInfo("Get any manual test run details associated with the build");
                globalManualTests = await getManualTestsForBuild(
                    organisationWebApi.rest,
                    testApi,
                    tpcUri,
                    teamProject,
                    buildId,
                    globalManualTestConfigurations);

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

                if (overrideBuildReleaseId && overrideBuildReleaseId.length > 0 ) {
                    if (isNaN(parseInt(overrideBuildReleaseId, 10))) {
                        agentApi.logError(`The override release ID '${overrideBuildReleaseId}' is not a number `);
                        resolve(-1);
                        return;
                    } else {
                        agentApi.logInfo (`Using the override for the last successful release of ID '${overrideBuildReleaseId}'`);
                    }
                }

                let mostRecentSuccessfulDeployment = await getMostRecentSuccessfulDeployment(
                    releaseApi,
                    teamProject,
                    releaseDefinitionId,
                    environmentId,
                    overrideBuildReleaseId,
                    considerPartiallySuccessfulReleases);
                let isInitialRelease = false;

                agentApi.logInfo(`Getting all artifacts in the current release...`);
                var artifactsInThisRelease = getSimpleArtifactArray(currentRelease.artifacts);
                buildId = await restoreAzurePipelineArtifactsBuildInfo(artifactsInThisRelease, organisationWebApi) || buildId; // update build id if using pipeline artifacts
                agentApi.logInfo(`Found ${artifactsInThisRelease.length} artifacts for current release`);

                let artifactsInMostRecentRelease: SimpleArtifact[] = [];
                if (mostRecentSuccessfulDeployment) {
                    // Get the release that the deployment was a part of - This is required for the templating.
                    mostRecentSuccessfulDeploymentRelease = await releaseApi.getRelease(teamProject, mostRecentSuccessfulDeployment.release.id);
                    agentApi.logInfo(`Getting all artifacts in the most recent successful release [${mostRecentSuccessfulDeployment.release.name}]...`);
                    artifactsInMostRecentRelease = getSimpleArtifactArray(mostRecentSuccessfulDeployment.release.artifacts);
                    await restoreAzurePipelineArtifactsBuildInfo(artifactsInMostRecentRelease, organisationWebApi);
                    mostRecentSuccessfulDeploymentName = mostRecentSuccessfulDeployment.release.name;
                    agentApi.logInfo(`Found ${artifactsInMostRecentRelease.length} artifacts for most recent successful release`);
                } else {
                    agentApi.logInfo(`Skipping fetching artifact in the most recent successful release as there isn't one.`);
                    // we need to set the last successful as the current release to templates can get some data
                    mostRecentSuccessfulDeploymentRelease = currentRelease;
                    mostRecentSuccessfulDeploymentName = "Initial Deployment";
                    artifactsInMostRecentRelease = artifactsInThisRelease;
                    isInitialRelease = true;
                }

                for (var artifactInThisRelease of artifactsInThisRelease) {
                    agentApi.logInfo(`Looking at artifact [${artifactInThisRelease.artifactAlias}]`);
                    agentApi.logInfo(`Artifact type [${artifactInThisRelease.artifactType}]`);
                    agentApi.logInfo(`Build Definition ID [${artifactInThisRelease.buildDefinitionId}]`);
                    agentApi.logInfo(`Build Number: [${artifactInThisRelease.buildNumber}]`);
                    agentApi.logInfo(`Is Primary: [${artifactInThisRelease.isPrimary}]`);

                    if ((showOnlyPrimary === false) || (showOnlyPrimary === true && artifactInThisRelease.isPrimary === true)) {
                        if (artifactsInMostRecentRelease.length > 0) {
                            if (artifactInThisRelease.artifactType === "Build") {
                                agentApi.logInfo(`Looking for the [${artifactInThisRelease.artifactAlias}] in the most recent successful release [${mostRecentSuccessfulDeploymentName}]`);
                                for (var artifactInMostRecentRelease of artifactsInMostRecentRelease) {
                                    if (artifactInThisRelease.artifactAlias.toLowerCase() === artifactInMostRecentRelease.artifactAlias.toLowerCase()) {
                                        agentApi.logInfo(`Found artifact [${artifactInMostRecentRelease.artifactAlias}] with build number [${artifactInMostRecentRelease.buildNumber}] in release [${mostRecentSuccessfulDeploymentName}]`);

                                        var commits: Change[];
                                        var workitems: ResourceRef[];
                                        var tests: TestCaseResult[];

                                        // Only get the commits and workitems if the builds are different
                                        if (isInitialRelease) {
                                            agentApi.logInfo(`This is the first release so checking what commits and workitems are associated with artifacts`);

                                            // there is a default of 1000 builds per definition returned returned by the API
                                            // but the continuation token is not supported, so we cannot get the next batch
                                            // we could all the API using the raw REST call, but building the url will be a bit more complex
                                            // so now just force the top value to it's max of 5000
                                            // this has no effect when there are fewer than 5000 builds in the definition
                                            let builds = await buildApi.getBuilds(artifactInThisRelease.sourceId, [parseInt(artifactInThisRelease.buildDefinitionId)],
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            undefined,
                                            5000,
                                            undefined,
                                            undefined,
                                            undefined,
                                            6 // startTimeDescending
                                        );

                                            commits = [];
                                            workitems = [];

                                            for (var build of builds) {
                                                try {
                                                    agentApi.logInfo(`Getting the details of build ${build.id}`);
                                                    var buildCommits = await (buildApi.getBuildChanges(teamProject, build.id, "", 5000));
                                                    commits.push(...buildCommits);
                                                    var buildWorkitems = await (buildApi.getBuildWorkItemsRefs(teamProject, build.id, 5000));
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
                                                    agentApi.logInfo("Using workaround for build API limitation (see issue #349)");
                                                    let baseBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInMostRecentRelease.buildId));
                                                    // There is only a workaround for Git but not for TFVC :(
                                                    if (baseBuild.repository.type === "TfsGit") {
                                                        let currentBuild = await buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInThisRelease.buildId));
                                                        let commitInfo = await issue349.getCommitsAndWorkItemsForGitRepo(organisationWebApi, baseBuild.sourceVersion, currentBuild.sourceVersion, currentBuild.repository.id);
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

                                                if (checkForManuallyLinkedWI) {
                                                    globalWorkItems = globalWorkItems.concat(await addMissingManuallyLinkedWI(buildApi, artifactInThisRelease.sourceId,  parseInt(artifactInThisRelease.buildDefinitionId), parseInt(artifactInMostRecentRelease.buildId),  parseInt(artifactInThisRelease.buildId)));
                                                }

                                            } catch (err) {
                                                agentApi.logWarn(`There was a problem getting the details of the CS/WI for the build ${err}`);
                                            }
                                        } else {
                                            commits = [];
                                            workitems = [];
                                            agentApi.logInfo(`Build for artifact [${artifactInThisRelease.artifactAlias}] has not changed.  Nothing to do`);
                                        }

                                        // enrich what we have with file names
                                        if (commits) {
                                            commits = await enrichChangesWithFileDetails(gitApi, tfvcApi, commits, gitHubPat);
                                        }

                                        // look for any test in the current build
                                        agentApi.logInfo(`Getting test associated with the latest build [${artifactInThisRelease.buildId}]`);
                                        tests = await getTestsForBuild(testApi, teamProject, parseInt(artifactInThisRelease.buildId));

                                        // get artifact details for the unified output format
                                        let artifact = await (buildApi.getBuild(artifactInThisRelease.sourceId, parseInt(artifactInThisRelease.buildId)));
                                        agentApi.logInfo(`Adding the build [${artifact.id}] and its associations to the unified results object`);

                                        if (commits) {
                                            globalCommits = globalCommits.concat(commits);
                                            agentApi.logInfo(`Detected ${commits.length} commits/changesets between the current build and the last successful one`);
                                        }

                                        if (workitems) {
                                            globalWorkItems = globalWorkItems.concat(workitems);
                                            agentApi.logInfo(`Detected  ${workitems.length} workitems between the current build and the last successful one`);
                                        }

                                        if (tests) {
                                            agentApi.logInfo(`Found ${tests.length} tests associated with the build [${artifactInThisRelease.buildId}] adding any not already in the global test list to the list`);
                                            // we only want to add unique items
                                            globalTests = addUniqueTestToArray(globalTests, tests);
                                        }

                                        var manualtests = await getManualTestsForBuild(
                                            organisationWebApi.rest,
                                            testApi,
                                            tpcUri,
                                            teamProject,
                                            artifact.id,
                                            globalManualTestConfigurations);
                                        if (manualtests) {
                                            agentApi.logInfo(`Found ${manualtests.length} manual tests associated with the build [${artifactInThisRelease.buildId}] adding any not already in the global test list to the list`);
                                            globalManualTests = globalManualTests.concat(manualtests);
                                        }

                                        // we need to enrich the WI before we associate with the build
                                        let fullBuildWorkItems = await getFullWorkItemDetails(workItemTrackingApi, workitems);

                                        globalBuilds.push(new UnifiedArtifactDetails(artifact, commits, fullBuildWorkItems, tests, manualtests));

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

            let expandedGlobalCommits = await expandTruncatedCommitMessages(organisationWebApi, globalCommits, gitHubPat, bitbucketUser, bitbucketSecret);

            if (!expandedGlobalCommits || expandedGlobalCommits.length !== globalCommits.length) {
                agentApi.logError("Failed to expand the global commits.");
                resolve(-1);
                return;
            }

            // by default order as returned by API
            if (sortCS) {
                agentApi.logInfo("Sorting CS by created date");
                globalCommits = globalCommits.sort(function(a, b) {
                    return a.timestamp < b.timestamp ? -1 : a.timestamp > b.timestamp ? 1 : 0;
                });
            } else {
                agentApi.logInfo("Leaving CS in default order as returned by API");
            }

            agentApi.logInfo("Find any WorkItems linked from GitHub using the AB#123 format");
            globalWorkItems = globalWorkItems.concat(await addGitHubLinkedWI(workItemTrackingApi, globalCommits));

            agentApi.logInfo("Removing duplicate WorkItems from master list");
            globalWorkItems = removeDuplicates(globalWorkItems);

            // get an array of workitem ids
            fullWorkItems = await getFullWorkItemDetails(workItemTrackingApi, globalWorkItems);

            if (getParentsAndChildren) {
                agentApi.logInfo("Getting direct parents and children of WorkItems");
                relatedWorkItems = await getAllDirectRelatedWorkitems(workItemTrackingApi, fullWorkItems);
            }

            if (getAllParents) {
                agentApi.logInfo("Getting all parents of known WorkItems");
                relatedWorkItems = await getAllParentWorkitems(workItemTrackingApi, relatedWorkItems);
            }

            if (wiqlWhereClause && wiqlWhereClause.length > 0) {
               var wiqlQuery = `SELECT [System.Id] FROM workitems WHERE ${wiqlWhereClause} ORDER BY [System.ID] DESC`;
               agentApi.logInfo(`Getting WorkItems using WIQL`);
               agentApi.logDebug(`SELECT [System.Id] FROM workitems WHERE ${wiqlWhereClause} ORDER BY [System.ID] DESC`);
               try {
                var queryResponse = await workItemTrackingApi.queryByWiql(
                    { query: wiqlQuery},
                    undefined,
                    undefined,
                    5000);
                    // need to get the result into the same format as used to enrich other WI arrays
                    var wiRefArray: ResourceRef[] = queryResponse.workItems.map(wi => ({id: wi.id.toString(), url: undefined})) as ResourceRef[];
                    // enrich the items
                    queryWorkItems = await getFullWorkItemDetails(workItemTrackingApi, wiRefArray);

                    agentApi.logInfo(`Found ${queryWorkItems.length} WI using WIQL`);

               } catch (ex) {
                   reject(ex);
                   agentApi.logError(`Failed to run WIQL ${ex.message}`);
                   resolve(-1);
                   return;
               }
            }

            // by default order by ID, has the option to group by type
            if (sortWi) {
                agentApi.logInfo("Sorting WI by type then id");
                fullWorkItems = fullWorkItems.sort((a, b) => (a.fields["System.WorkItemType"] > b.fields["System.WorkItemType"]) ? 1 : (a.fields["System.WorkItemType"] === b.fields["System.WorkItemType"]) ? ((a.id > b.id) ? 1 : -1) : -1 );
                queryWorkItems = queryWorkItems.sort((a, b) => (a.fields["System.WorkItemType"] > b.fields["System.WorkItemType"]) ? 1 : (a.fields["System.WorkItemType"] === b.fields["System.WorkItemType"]) ? ((a.id > b.id) ? 1 : -1) : -1 );
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
                        globalPullRequests.push(<EnrichedGitPullRequest>prDetails);
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
                    agentApi.logInfo(`Found ${allPullRequests.length} Azure DevOps PRs in the repo`);
                    globalCommits.forEach(commit => {
                        if (commit.type === "TfsGit") {
                            agentApi.logInfo(`Checking for PRs associated with the commit ${commit.id}`);

                            allPullRequests.forEach(pr => {
                                if (pr.lastMergeCommit) {
                                    if (pr.lastMergeCommit.commitId === commit.id) {
                                        agentApi.logInfo(`- PR ${pr.pullRequestId} matches the commit ${commit.id}`);
                                        globalPullRequests.push(<EnrichedGitPullRequest>pr);
                                    }
                                } else {
                                    agentApi.logInfo(`- PR ${pr.pullRequestId} does not have a lastMergeCommit`);
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

            agentApi.logInfo(`Enriching known Pull Requests`);
            globalPullRequests = await enrichPullRequest(gitApi, globalPullRequests);

            if (getIndirectPullRequests === true ) {
                agentApi.logInfo(`Checking the CS associated with the PRs to see if they are inturn associated PRs`);
                if (allPullRequests && allPullRequests.length > 0 ) {
                    for (let prIndex = 0; prIndex < globalPullRequests.length; prIndex++) {
                        const pr = globalPullRequests[prIndex];
                        for (let csIndex = 0; csIndex < pr.associatedCommits.length; csIndex++) {
                            const cs =  pr.associatedCommits[csIndex];
                            var foundPR = allPullRequests.find( e => e.lastMergeCommit && e.lastMergeCommit.commitId === cs.commitId);
                            if (foundPR) {
                            agentApi.logInfo(`Found the PR ${foundPR.pullRequestId} associated wth ${cs.commitId} added to the 'inDirectlyAssociatedPullRequests' array`);
                            inDirectlyAssociatedPullRequests.push(<EnrichedGitPullRequest>foundPR);
                            }
                        }
                    }
                }
                // enrich the founds PRs
                await enrichPullRequest(gitApi, inDirectlyAssociatedPullRequests);
            }

        } catch (ex) {
            agentApi.logInfo(`The most common runtime reason for the task to fail is due API ECONNRESET issues. To avoid this failing the pipeline these will be treated as warnings and an attempt to generate any release notes possible`);
            agentApi.logWarn(ex);
            hasBeenTimeout = true;
        }

        try {
            agentApi.logInfo(`Total Builds: [${globalBuilds.length}]`);
            agentApi.logInfo(`Total Commits: [${globalCommits.length}]`);
            agentApi.logInfo(`Total Workitems: [${globalWorkItems.length}]`);
            agentApi.logInfo(`Total Related Workitems (Parent/Children): [${relatedWorkItems.length}]`);
            agentApi.logInfo(`Total Release Tests: [${releaseTests.length}]`);
            agentApi.logInfo(`Total Tests: [${globalTests.length}]`);
            agentApi.logInfo(`Total Manual Test Runs: [${globalManualTests.length}]`);
            agentApi.logInfo(`Total Manual Test Configurations: [${globalManualTestConfigurations.length}]`);
            agentApi.logInfo(`Total Pull Requests: [${globalPullRequests.length}]`);
            agentApi.logInfo(`Total Indirect Pull Requests: [${inDirectlyAssociatedPullRequests.length}]`);
            agentApi.logInfo(`Total Consumed Artifacts: [${globalConsumedArtifacts.length}]`);
            agentApi.logInfo(`Total WIQL Workitems: [${queryWorkItems.length}]`);

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
                    currentStage: currentStage,
                    inDirectlyAssociatedPullRequests: inDirectlyAssociatedPullRequests,
                    manualTests: globalManualTests,
                    manualTestConfigurations: globalManualTestConfigurations,
                    consumedArtifacts: globalConsumedArtifacts,
                    queryWorkItems: queryWorkItems
                });

            agentApi.logInfo(`Generating the release notes, the are ${templateFiles.length} template(s) to process`);
            for (let i = 0; i < templateFiles.length; i++) {
                var template = getTemplate (templateLocation, templateFiles[i], inlineTemplate);
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
                        currentStage,
                        inDirectlyAssociatedPullRequests,
                        globalManualTests,
                        globalManualTestConfigurations,
                        stopOnError,
                        globalConsumedArtifacts,
                        queryWorkItems);

                    writeFile(outputFiles[i], outputString, replaceFile, appendToFile);

                    if (i === 0) {
                        agentApi.logInfo(`Output variable '${outputVariableName}' set to value of first generated release notes`);
                        agentApi.writeVariable(outputVariableName, outputString.toString());
                    }

                    if (hasBeenTimeout) {
                        // we want to return -1 so flagged as succeeded with issues
                        resolve(-1);
                    } else {
                        resolve(0);
                    }
                } else {
                    reject ("Missing template file");
                }
            }
        } catch (ex) {
            agentApi.logError(ex);
            reject (ex);
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

async function enrichConsumedArtifacts(
    consumedArtifacts,
    buildApi,
    workItemTrackingApi): Promise<[]> {
    return new Promise<[]>(async (resolve, reject) => {
    try {
        for (let index = 0; index < consumedArtifacts.length; index++) {
            const artifact = consumedArtifacts[index];
            if (artifact["artifactCategory"] === "Pipeline") {
                agentApi.logInfo(`Getting the commit and work item details of the '${artifact["artifactCategory"]}' artifact '${artifact["alias"]}' with the version name '${artifact["versionName"]}'`);
                try {
                    var artifactTeamProjectId = artifact["properties"]["projectId"];
                    artifact["commits"] = await (buildApi.getBuildChanges(artifactTeamProjectId, artifact["versionId"], "", 5000));
                    artifact["workitems"] = await getFullWorkItemDetails(workItemTrackingApi, await (buildApi.getBuildWorkItemsRefs(artifactTeamProjectId, artifact["versionId"], 5000)));
                } catch (err) {
                    agentApi.logWarn(`Cannot retried commit or work item information ${err}`);
                }
            } else {
                agentApi.logInfo(`Cannot get extra commit or work item details of the ${artifact["artifactCategory"]} artifact ${artifact["alias"]} ${artifact["versionName"]}`);
            }
        }
        resolve(consumedArtifacts);
    } catch (err) {
        reject (err);
    }
});
}

// #1103 this function is a belt an braces means to get all the WI associated with a build
// ones manually link to a build are not found with the wi between builds call
// this block is only called when the extra flag is abled as it is expensive on the API
// we return duplicates WI, but they will be filtered before being passed to the processor
async function addMissingManuallyLinkedWI(buildApi: IBuildApi, TeamProjectId: any,  BuildDefId: number, FromBuild: number, ToBuild: number): Promise<ResourceRef[]> {
    return new Promise<ResourceRef[]>(async (resolve, reject) => {
        var workItems = [];
        try {
            agentApi.logInfo(`Getting WI associated with builds between ${FromBuild} to ${ToBuild} to make sure we find ones manually linked to build`);

            // this is expensive, but we need to get the work items that are not linked to the build
            var builds = await buildApi.getBuilds(TeamProjectId, [BuildDefId]);

            for (let index = 0; index < builds.length; index++) {
                const build = builds[index];
                if (build.id > FromBuild && build.id <= ToBuild) {
                    var buildWi = await buildApi.getBuildWorkItemsRefs(TeamProjectId, build.id, 5000);
                    agentApi.logDebug(`Checking build ${build.id} found ${buildWi.length} WI`);
                    workItems = workItems.concat(buildWi);
                }
            }

            agentApi.logDebug(`Adding ${workItems.length} found with potential manual links, these will be added to the global list and duplicates removed later`);
            resolve (workItems);
    } catch (err) {
        reject (err);
    }
});
}

async function addGitHubLinkedWI(workItemTrackingApi: IWorkItemTrackingApi, globalCommits: Change[]): Promise<ResourceRef[]> {
    return new Promise<ResourceRef[]>(async (resolve, reject) => {
        var workItems = [];
        try {
            if (globalCommits) {
                for (var commitIndex = 0; commitIndex < globalCommits.length; commitIndex++) {
                    var commit = globalCommits[commitIndex];
                    if (commit.type && commit.type === "GitHub") {
                        // this is a commit from github, so check for AB#123 links
                        agentApi.logDebug(`The commit ${commit.id.substring(0, 7)} is from a GitHub hosted repo`);
                        if (commit.message) {
                            var linkedWIs = commit.message.match(/(ab#)[0-9]+/ig);
                            if (linkedWIs) {
                                agentApi.logDebug(`Found ${linkedWIs.length} workitems linked using the AB#123 format, attempting to find details`);
                                for (let wiIndex = 0; wiIndex < linkedWIs.length; wiIndex++) {
                                    const wi = Number(linkedWIs[wiIndex].substr(3));
                                    var wiDetail = await workItemTrackingApi.getWorkItem(wi, null, null, WorkItemExpand.All, null);
                                    if (wiDetail) {
                                        agentApi.logDebug(`Adding details of workitem ${wi}`);
                                        workItems.push(wiDetail);
                                    } else {
                                        agentApi.logDebug(`Cannot find workitem with Id ${wi}`);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            agentApi.logInfo(`Adding ${workItems.length} found using AB#123 links in GitHub comments`);
            resolve (workItems);
        } catch (err) {
            reject (err);
        }
    });
}
