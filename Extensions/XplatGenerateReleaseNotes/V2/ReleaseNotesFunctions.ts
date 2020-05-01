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
    constructor ( build: Build, commits: Change[], workitems: ResourceRef[]) {
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
   }
}

import * as restm from "typed-rest-client/RestClient";
import { HttpClient } from "typed-rest-client/HttpClient";
import tl = require("azure-pipelines-task-lib/task");
import { ReleaseEnvironment, Artifact, Deployment, DeploymentStatus, Release } from "azure-devops-node-api/interfaces/ReleaseInterfaces";
import { IAgentSpecificApi, AgentSpecificApi } from "./agentSpecific";
import { IReleaseApi } from "azure-devops-node-api/ReleaseApi";
import { IRequestHandler } from "azure-devops-node-api/interfaces/common/VsoBaseInterfaces";
import * as webApi from "azure-devops-node-api/WebApi";
import fs  = require("fs");
import { ResourceRef } from "azure-devops-node-api/interfaces/common/VSSInterfaces";
import { Build, Change } from "azure-devops-node-api/interfaces/BuildInterfaces";
import { IGitApi, GitApi } from "azure-devops-node-api/GitApi";
import { GitCommit, GitPullRequest, GitPullRequestQueryType, GitPullRequestSearchCriteria, PullRequestStatus } from "azure-devops-node-api/interfaces/GitInterfaces";
import { WorkItem } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";
import { WebApi } from "azure-devops-node-api";

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

export async function expandTruncatedCommitMessages(restClient: WebApi, globalCommits: Change[]): Promise<Change[]> {
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
                            let rc = new restm.RestClient("rest-client");
                            let gitHubRes: any = await rc.get(change.location); // we have to use type any as  there is a type mismatch
                            if (gitHubRes.statusCode === 200) {
                                change.message = gitHubRes.result.commit.message;
                                change.messageTruncated = false;
                                expanded++;
                            } else {
                                agentApi.logWarn(`Cannot access API ${gitHubRes.statusCode}`);
                                agentApi.logWarn(`Using ${change.location}`);
                            }
                        } else {
                            agentApi.logDebug(`Need to expand details from Azure DevOps`);
                            let vstsRes = await restClient.rest.get<GitCommit>(change.location);
                            if (vstsRes.statusCode === 200) {
                                change.message = vstsRes.result.comment;
                                change.messageTruncated = false;
                                expanded++;
                            } else {
                                agentApi.logWarn(`Cannot access API ${vstsRes.statusCode}`);
                                agentApi.logWarn(`Using ${change.location}`);
                            }
                        }
                    } catch (err) {
                        agentApi.logWarn(`Cannot expand message ${err}`);
                        agentApi.logWarn(`Using ${change.location}`);
                    }
                }
            }
            resolve(globalCommits);
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
    customHandlebarsExtensionCode,
    prDetails,
    pullRequests: GitPullRequest[],
    globalBuilds: UnifiedArtifactDetails[]): string {

    var widetail = undefined;
    var csdetail = undefined;
    var lastBlockStartIndex;
    var output = "";

    if (template.length > 0) {
        agentApi.logDebug("Processing template");
        agentApi.logDebug(`WI: ${workItems.length}`);
        agentApi.logDebug(`CS: ${commits.length}`);
        agentApi.logDebug(`PR: ${pullRequests.length}`);
        agentApi.logDebug(`B: ${globalBuilds.length}`);

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

            var customHandlebarsExtensionFile = "customHandlebarsExtension";
            // cannot use process.env.Agent_TempDirectory as only set on Windows agent, so build it up from the agent base
            // Note that the name is case sensitive on Mac and Linux
            var customHandlebarsExtensionFolder = `${process.env.AGENT_WORKFOLDER}/_temp`;
            agentApi.logDebug(`Saving custom handles code to file in folder ${customHandlebarsExtensionFolder}`);

            if (typeof customHandlebarsExtensionCode !== undefined && customHandlebarsExtensionCode && customHandlebarsExtensionCode.length > 0) {
                agentApi.logInfo("Loading custom handlebars extension");
                writeFile(`${customHandlebarsExtensionFolder}/${customHandlebarsExtensionFile}.js`, customHandlebarsExtensionCode);
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
                "builds": globalBuilds
             });
        }

        agentApi.logInfo( "Completed processing template");
    } else {
        agentApi.logError( `Cannot load template file [${template}] or it is empty`);
    }  // if no template

    return output;
}

export function writeFile(filename: string, data: string) {
    agentApi.logInfo(`Writing output file ${filename}`);
    fs.writeFileSync(filename, data, "utf8");
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