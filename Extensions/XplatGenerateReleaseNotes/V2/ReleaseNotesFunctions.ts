export interface SimpleArtifact {
    artifactAlias: string;
    buildDefinitionId: string;
    buildNumber: string;
    buildId: string;
    artifactType: string;
}

import * as restm from "typed-rest-client/RestClient";
import tl = require("vsts-task-lib/task");
import { ReleaseEnvironment, Artifact, Deployment, DeploymentStatus, Release } from "vso-node-api/interfaces/ReleaseInterfaces";
import { IAgentSpecificApi, AgentSpecificApi } from "./agentSpecific";
import { IReleaseApi } from "vso-node-api/ReleaseApi";
import { IRequestHandler } from "vso-node-api/interfaces/common/VsoBaseInterfaces";
import * as webApi from "vso-node-api/WebApi";
import fs  = require("fs");
import { ResourceRef } from "vso-node-api/interfaces/common/VSSInterfaces";
import { Build, Change } from "vso-node-api/interfaces/BuildInterfaces";
import { IGitApi } from "vso-node-api/GitApi";
import { GitCommit } from "vso-node-api/interfaces/GitInterfaces";
import { HttpClient } from "typed-rest-client/HttpClient";
import { WorkItem } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";
import { type } from "os";

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
                "artifactType": artifact.type
            }
        );
    }
    return result;
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

export async function expandTruncatedCommitMessages(restClient: restm.RestClient, globalCommits: Change[]): Promise<Change[]> {
    return new Promise<Change[]>(async (resolve, reject) => {
        try {
            var expanded: number = 0;
            agentApi.logInfo(`Expanding the truncated commit messages...`);
            for (var change of globalCommits) {
                if (change.messageTruncated) {
                    agentApi.logDebug(`Expanding commit [${change.id}]`);
                    let res: restm.IRestResponse<GitCommit> = await restClient.get<GitCommit>(change.location);

                    if (res.statusCode === 200) {
                        change.message = res.result.comment;
                        change.messageTruncated = false;
                        expanded++;
                    } else {
                        agentApi.logDebug(`Failed to get the full commit message for ${change.id}`);
                    }
                }
            }
            agentApi.logInfo(`Finished expanding [${expanded}] commits.`);
            resolve(globalCommits);
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

export function getTemplate(
        templateLocation: string,
        templatefile: string ,
        inlinetemplate: string
    ): Array<string> {
        agentApi.logDebug(`Using template mode ${templateLocation}`);
        var template;
        if (templateLocation === "File") {
            agentApi.logInfo (`Loading template file ${templatefile}`);
        template = fs.readFileSync(templatefile).toString().split("\n");
        } else {
            agentApi.logInfo ("Using in-line template");
            // it appears as single line we need to split it out
            template = inlinetemplate.split("\n");
        }
        return template;
}

// The Argument compareReleaseDetails is used in the template processing.  Renaming or removing will break the templates
export function processTemplate(template, workItems: WorkItem[], commits: Change[], buildDetails: Build, releaseDetails: Release, compareReleaseDetails: Release, emptySetText, delimiter): string {

    var widetail = undefined;
    var csdetail = undefined;
    var lastBlockStartIndex;
    var output = "";

    if (template.length > 0) {
        agentApi.logDebug("Processing template");
        agentApi.logDebug(`WI: ${workItems.length}`);
        agentApi.logDebug(`CS: ${commits.length}`);
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
           var wiFilter = getModeTags(line, delimiter);

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
                        if (wiFilter.tags.length > 0) {
                            widetail = undefined;
                            workItems.forEach(wi => {
                                agentApi.logDebug (`${addSpace(modeStack.length + 2)} Checking WI ${wi.id} tags '${wi.fields["System.Tags"]}' against '${wiFilter.tags.sort().join("; ")}' (ignoring case) using comparison filter '${wiFilter.modifier}'`);
                                switch (wiFilter.modifier) {
                                    case Modifier.All:
                                        if ((wi.fields["System.Tags"] !== undefined) &&
                                            (wi.fields["System.Tags"].toUpperCase() === wiFilter.tags.join("; ").toUpperCase())) {
                                            agentApi.logDebug (`${addSpace(modeStack.length + 2)} Adding WI ${wi.id} as all tags match`);
                                            modeArray.push(wi);
                                        }
                                        break;
                                    case Modifier.ANY:
                                        if ((wi.fields["System.Tags"] !== undefined)) {
                                            for (let tag of wiFilter.tags) {
                                                if (wi.fields["System.Tags"].toUpperCase().indexOf(tag.toUpperCase()) !== -1) {
                                                    agentApi.logDebug (`${addSpace(modeStack.length + 2)} Adding WI ${wi.id} as at least one tag matches`);
                                                    modeArray.push(wi);
                                                    break;
                                                }
                                            }
                                        }
                                        break;
                                    default:
                                        agentApi.logWarn (`${addSpace(modeStack.length + 2)} Invalid filter passed, skipping WI ${wi.id}`);
                                }
                            });
                        } else {
                            agentApi.logDebug (`${addSpace(modeStack.length + 2)} Adding all WI`);
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
                        // store the block and load the first item
                        addStackItem (commits, modeStack, line, index);
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
        agentApi.logInfo( "Completed processing template");
    } else {
        agentApi.logError( `Cannot load template file [${template}] or it is empty`);
    }  // if no template

    return output;
}

export function writeFile(filename: string, data: string) {
    agentApi.logInfo(`Writing output file ${filename}`);
    fs.writeFileSync(filename, data);
    agentApi.logInfo(`Finsihed writing output file ${filename}`);
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
}

export function getMode (line): string {
     var mode = Mode.BODY;
     if (line !== undefined ) {
        line = line.trim().toUpperCase();
        if (line.startsWith("@@WILOOP") && line.endsWith("@@")) {
            mode = Mode.WI;
        }
        if (line.startsWith("@@CSLOOP@@") &&
            line.endsWith("@@") ) {
            mode = Mode.CS;
        }
    }
    return mode;
}

export function getModeTags (line, delimiter): WiFilter {
    line = line.trim().toUpperCase();
    var filter = new WiFilter();
    filter.modifier = Modifier.All;
    filter.tags = [];
    if (line.startsWith("@@") && line.endsWith("@@") ) {
        line = line.replace(/@@/g, ""); // have to use regex form of replace else only first replaced
        var match = line.match(/(\[.*?\])/g);
        if (match !== null && match.toString() === "[ANY]") {
            filter.modifier = Modifier.ANY;
        }
        var parts = line.split(delimiter);
        if (parts.length > 1) {
            parts.splice(0, 1); // return the tags
            filter.tags = parts; // return the tags
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

function addSpace (indent): string {
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
    return  "\"" + line.trim().split("${").join("\" + ").split("}").join(" + \"") + "\"";
}