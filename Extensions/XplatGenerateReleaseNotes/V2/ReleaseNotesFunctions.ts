// // all the functions that are common to local testing and VSTS usage

// import request = require("request");
// import fs  = require("fs");

// import { logDebug,
//          logWarning,
//          logInfo,
//          logError
//  }  from "./agentSpecific";

// export function encodePat(pat) {
//    var b = new Buffer(":" + pat);
//    var s = b.toString("base64");
//    return s;
// }

// export function getPrimaryBuildIdFromRelease(details) {
//     var id = NaN;
//     details.artifacts.forEach(artifact => {
//         if (artifact.isPrimary === true) {
//             id = artifact.definitionReference.version.id;
//         }
//     });
//     return id;
// }

// export function getBuild(vstsinstance: string, teamproject: string, encodedPat: string, buildId): Promise<any>  {
//     return new Promise<any>((resolve, reject) => {
//         var options = {
//         method: "GET",
//         headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}` },
//         url: `${vstsinstance}/${teamproject}/_apis/Build/Builds/${buildId}`,
//         qs: { "api-version": "2.0" }
//         };
//         logInfo(`Getting the details of build ${buildId}`);
//         request(options, function (error, response, body) {
//             if (error) {
//                 reject(error);
//             }
//             var build = JSON.parse(body);
//                 resolve(build);
//         });
//     });
// }

// export function  getBuildDefinition(vstsinstance: string, teamproject: string, encodedPat: string, buildDefId, callback)  {
//     var options = {
//       method: "GET",
//       headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}` },
//       url: `${vstsinstance}/${teamproject}/_apis/build/definitions/${buildDefId}`,
//       qs: { "api-version": "2.0" }
//     };
//     logInfo(`Getting the details of build definition ${buildDefId}`);
//     request(options, function (error, response, body) {
//       if (error) {
//         throw new Error(error);
//       }
//       var build = JSON.parse(body);
//       return  callback(build);
//     });

// }

// export async function getPastSuccessfulRelease(vstsinstance, teamproject, encodedPat, currentReleaseDetails, stage): Promise<any> {
//     return new Promise<any>((resolve, reject) => {
//         // get all releases
//         // loop back to find last "succeeded"
//         // get this build
//         var options = {
//             method: "GET",
//             headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}` },
//             url: `${fixRmUrl(vstsinstance)}/${teamproject}/_apis/release/releases?definitionId=${currentReleaseDetails.releaseDefinition.id}&$Expand=environments,artifacts&queryOrder=descending`,
//             qs: { "api-version": "3.0-preview" }
//         };
//         logInfo(`Getting the details of last release using definiton '${currentReleaseDetails.releaseDefinition.name}' that was successful in environment '${stage}' `);
//         request(options, async function (error, response, body) {
//             if (error) {
//                 reject(error);
//             }
//             var releases = JSON.parse(body);
//             var earliestId = 0;
//             var successfulReleases = [];

//             for (let release of releases.value) {

//                 // Get details fo release - this is required so we can get details of multiple deployments to the same environment
//                 var releaseDeatils = await getRelease(vstsinstance, teamproject, encodedPat, release.id);

//                 for (let environment of releaseDeatils.environments) {
//                     // make sure we check that we are not seeing the current active release
//                     // we have to trap to see if we have found a release ID as there is no break; out of foreach in Javascript
//                     if ((environment.name === stage)) {
//                         // This is the right environment
//                         for (let deployment of environment.deploySteps) {
//                             if (deployment.status === "succeeded") {
//                                 successfulReleases.push({
//                                     releaseId: release.id,
//                                     queuedOn: deployment.job.finishTime
//                                 });
//                             }
//                         }
//                     }
//                     // we need to check if there was no successful release
//                     if ((earliestId === 0) || (release.id < earliestId)) {
//                         earliestId = release.id;
//                     }
//                 }
//             }

//             var releaseId = 0;

//             // no valid release so we will use the oldest release
//             if (successfulReleases.length === 0) {
//                 logInfo(`Can not find successful release to the requested stage, using first release as baseline`);
//                 releaseId = earliestId;
//             } else {
//                 logInfo(`Found '${successfulReleases.length}' successful releases.  Sorting them to find the most recent successful deployment.`);

//                 for ( let i = 0; i < successfulReleases.length; i++) {
//                     logInfo(`ReleaseId: '${successfulReleases[i].releaseId}', Date: '${successfulReleases[i].queuedOn}'`);
//                 }

//                 // We need to loop through the successful releases and try to find the latest (by queuedOn) successful
//                 successfulReleases = successfulReleases.sort(function(a, b) {
//                     return +new Date(b.queuedOn) - +new Date(a.queuedOn);
//                 });

//                 for (let i = 0; i < successfulReleases.length; i++) {
//                     logInfo(`ReleaseId: '${successfulReleases[i].releaseId}', Date: '${successfulReleases[i].queuedOn}'`);
//                 }

//                 // Take the first one
//                 releaseId = successfulReleases[0].releaseId;
//             }

//             logInfo(`Most recent successful release: '${releaseId}'`);

//             resolve(getRelease(vstsinstance, teamproject, encodedPat, releaseId));

//         });
//     });
// }

// export function getRelease(vstsinstance: string, teamproject: string, encodedPat: string, releaseId): Promise<any>  {
//     return new Promise<any>((resolve, reject) => {
//         var options = {
//             method: "GET",
//             headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}` },
//             url: `${fixRmUrl(vstsinstance)}/${teamproject}/_apis/Release/releases/${releaseId}`,
//             qs: { "api-version": "3.1-preview.1"}
//         };
//         logInfo(`Getting the details of release ${releaseId}`);
//         request(options, function (error, response, body) {
//             if (error) {
//                 logInfo(`Error in getRelease: ${options.url}`);
//                 reject(error);
//             }
//             try {
//                 var release = JSON.parse(body);
//                 resolve(release);
//             } catch (e) {
//                 logInfo(`Error in parsing the response from: ${options.url}`);
//                 logInfo(`ResponseBody: ${body}`);
//                 reject(e);
//             }
//         });
//     });

// }

// export function getWorkItemBetweenReleases(vstsinstance: string, teamproject: string, encodedPat: string, releaseId, compareId): Promise<any>  {
//     return new Promise<any>((resolve, reject) => {
//         var options = {
//         method: "GET",
//         headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}`},
//         url: `${fixRmUrl(vstsinstance)}/${teamproject}/_apis/Release/releases/${releaseId}/workitems?baseReleaseId=${compareId}&%24top=250`,
//         qs: { "api-version": "3.1-preview.1" }
//         };
//         logInfo(`Getting the workitems associated between release ${releaseId} and release ${compareId}`);
//         request(options, function (error, response, body) {
//             if (error) {
//                 reject(error);
//                 throw new Error(error);
//             }
//             var workItems = JSON.parse(body);
//             resolve(workItems.value);
//         });
//     });
// }

// export function getCommitsBetweenCommitIds (
//                              vstsinstance: string,
//                              teamproject: string,
//                              encodedPat: string,
//                              repositoryType,
//                              buildDefId,
//                              repositoryId,
//                              currentSourceVersion,
//                              compareSourceVersion): Promise<Array<any>>  {

//     return new Promise<any>((resolve, reject) => {
//         logInfo(`Repository type ${repositoryType}`);

//         if (currentSourceVersion === compareSourceVersion) {
//             logInfo(`[${currentSourceVersion}] is equal to [${compareSourceVersion}] - There are no commits/changesets. Skipping...`);
//             resolve([]);
//             return;
//         }

//         if (repositoryType === "TfsGit") {
//             // the item and compare are note the obvious way around, in the rest of the task we have current and compare to an old version
//             // this call takes an old version as the base and compares later versions, hence the revise
//             var data =   `{"itemPath":"","user":null,"$top":250,"itemVersion":{"versionType":"commit","version":"${compareSourceVersion}"},"compareVersion":{"versionType":"commit","version":"${currentSourceVersion}"}}`;
//             var options = {
//                 method: "POST",
//                 headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}`, "Content-Type": "application/json"},
//                 url: `${vstsinstance}/${teamproject}/_apis/git/repositories/${repositoryId}/commitsBatch`,
//                 qs: { "api-version": "3.1" },
//                 json : JSON.parse(data)
//             };

//                 logInfo(`Getting the commits between commit ID ${currentSourceVersion} and ${compareSourceVersion} from repo ${repositoryId}`);
//                 request(options, function (error, response, body) {
//                 if (error) {
//                     reject(error);
//                 }
//                 resolve(body.value);
//             });
//         } else if (repositoryType === "TfsVersionControl") {
//             // for TfVC it is more complex
//             // first we need to get the build definition
//             getBuildDefinition (vstsinstance, teamproject, encodedPat, buildDefId, function(details) {
//                 // we need to extract the active mappings and check for changes on each of
//                 // these paths in turn. The VSTS UI uses a non-REST call that allows an
//                 // array to be passed, but this does not seem to be available to third parties

//                 var mappings =  [];
//                 for (let element of JSON.parse(details.repository.properties.tfvcMapping).mappings) {
//                     if (element.mappingType === "map") {
//                         mappings.push(element.serverPath);
//                     }
//                 }

//                 // Using this pattern http://stackoverflow.com/questions/750486/javascript-closure-inside-loops-simple-practical-example?rq=1
//                 var allDetails = [];
//                 // as javascript functions are async, we have to put a count check in to
//                 // return when all the mappings are checked - kludge but best way I know of
//                 var count = 0;
//                 for ( let mapping of mappings) {
//                     getTfvcDetails(
//                         vstsinstance,
//                         teamproject,
//                         encodedPat,
//                         repositoryId,
//                         compareSourceVersion,
//                         currentSourceVersion,
//                         mapping,
//                         function(details) {
//                                 count ++;
//                                 allDetails.push.apply(allDetails, details);
//                                 if (count === mappings.length) {
//                                     resolve(allDetails);
//                                 }
//                         });
//                 }
//             }); // get build def
//         } else {
//             logInfo(`Cannot get any commit/changeset details as build based on none VSTS repository`);
//             resolve([]);
//             return;
//         } // if Git/Tfvc
//     });
// }

// function getTfvcDetails(vstsinstance: string,
//                         teamproject: string,
//                         encodedPat: string,
//                         repositoryId: string,
//                         compareSourceVersion: string,
//                         currentSourceVersion: string,
//                         mappings: string,
//                         callback) {
//     // the call parameters use inclusive bounds, we need to exclude the lower one
//     var fixedLowerBound = parseInt(compareSourceVersion);
//     fixedLowerBound ++;
//     logInfo(`Excluding the lower Changeset as inclusives bounds required ${compareSourceVersion} replaced by ${fixedLowerBound}`);

//     var options = {
//         method: "GET",
//         headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}`, "Content-Type": "application/json"},
//         url: `${vstsinstance}/${teamproject}/_apis/tfvc/changesets?searchCriteria.fromId=${fixedLowerBound}&searchCriteria.toId=${currentSourceVersion}&searchCriteria.itemPath=${mappings}&maxCommentLength=1000&$top=1000`,
//         qs: { "api-version": "1.0" },
//     };
//     logInfo(`Getting the differences between changeset with an ID greater than ${compareSourceVersion} up to and including ${currentSourceVersion} from repo ${repositoryId} for mapping ${mappings}`);
//     request(options, function (error, response, body) {
//         if (error) {
//             throw new Error(error);
//         }
//         var data = JSON.parse(body);
//         return callback(data.value);
//     });
// }

// export function getWorkItems(vstsinstance: string, encodedPat: string, ids): Promise<any>  {
//     return new Promise<any>((resolve, reject) => {
//         var options = {
//         method: "GET",
//         headers: { "cache-control": "no-cache", "authorization": `Basic ${encodedPat}` },
//         url: `${vstsinstance}/_apis/wit/workitems?ids=${ids}&api-version=1.0`,
//         qs: { "api-version": "1.0" }
//         };

//         if (ids) {
//             logInfo(`Getting the workitem details for ${ids}`);
//             request(options, function (error, response, body) {
//                 if (error) {
//                     reject(error);
//                 }
//                 var workItems = JSON.parse(body);
//                 resolve(workItems.value);
//             });
//         } else {
//             logInfo(`No workitems requested for which to get details`);
//             resolve(null);
//         }
//     });
// }

// export function getTemplate(
//         templateLocation: string,
//         templatefile: string ,
//         inlinetemplate: string
//     ): Array<string> {
//     logDebug(`Using template mode ${templateLocation}`);
//     var template;
//     if (templateLocation === "File") {
//         logInfo (`Loading template file ${templatefile}`);
//         template = fs.readFileSync(templatefile).toString().split("\n");
//    } else {
//         logInfo ("Using in-line template");
//         // it appears as single line we need to split it out
//         template = inlinetemplate.split("\n");
//     }
//     return template;
// }

// export function processTemplate(template, workItems, commits, releaseDetails, compareReleaseDetails, emptySetText): string {
//     var commits; // to move to param
//     var widetail = undefined;
//     var csdetail = undefined;
//     var lastBlockStartIndex;
//     var output = "";

//     if (template.length > 0) {
//         logInfo("Processing template");
//         // create our work stack and initialise
//         var modeStack = [];
//         modeStack.push(Mode.BODY);

//       // process each line
//       for (var index = 0; index < template.length; index++) {
//           logInfo("Processing Line: " + (index + 1));
//           var line = template[index];

//           // get the line change mode if any
//           var mode = getMode(line);

//           if (mode !== Mode.BODY) {
//               // is there a mode block change
//               if (modeStack[modeStack.length - 1].Mode === mode) {
//                   // this means we have reached the end of a block
//                   // need to work out if there are more items to process
//                   // or the end of the block
//                   var queue = modeStack[modeStack.length - 1].BlockQueue;
//                   if (queue.length > 0) {
//                       // get the next item and initialise
//                       // the variables exposed to the template
//                       var item = queue.shift();
//                       // reset the index to process the block
//                       index = modeStack[modeStack.length - 1].Index;
//                       switch (mode) {
//                         case Mode.WI :
//                                 logDebug (`${addSpace(modeStack.length + 1)} Getting next workitem ${item.id}`);
//                                 widetail = item;
//                                 break;
//                         case Mode.CS :
//                              if (csdetail.commitId) {
//                                  // Git mode
//                                  logDebug (`${addSpace(modeStack.length + 1)} Getting next commit ${item.commitId}`);
//                              } else {
//                                 // TFVC mode
//                                 logDebug (`${addSpace(modeStack.length + 1)} Getting next changeset ${item.changesetId}`);
//                              }
//                               csdetail = item;
//                               break;
//                       } // end switch
//                   } else {
//                       // end of block and no more items, so exit the block
//                       mode = modeStack.pop().Mode;
//                       logDebug (`${addSpace(modeStack.length + 1)} Ending block ${mode}`);
//                   }
//               } else {
//                   // this a new block to add the stack
//                   // need to get the items to process and place them in a queue
//                   logDebug (`${addSpace(modeStack.length + 1)} Starting block ${mode}`);

//                   // set the index to jump back to
//                   lastBlockStartIndex = index;
//                   switch (mode) {
//                       case Mode.WI:
//                         // store the block and load the first item
//                         addStackItem (workItems, modeStack, mode, index);
//                         if (modeStack[modeStack.length - 1].BlockQueue.length > 0) {
//                              widetail = modeStack[modeStack.length - 1].BlockQueue.shift();
//                              logDebug (`${addSpace(modeStack.length + 1)} Getting first workitem ${widetail.id}`);
//                         } else {
//                              widetail = undefined;
//                         }
//                         break;
//                       case Mode.CS:
//                          // store the block and load the first item
//                          addStackItem (commits, modeStack, mode, index);
//                          if (modeStack[modeStack.length - 1].BlockQueue.length > 0) {
//                              csdetail = modeStack[modeStack.length - 1].BlockQueue.shift();
//                              if (csdetail.commitId) {
//                                  // Git mode
//                                  logDebug (`${addSpace(modeStack.length + 1)} Getting first commit ${csdetail.commitId}`);
//                              } else {
//                                 // TFVC mode
//                                 logDebug (`${addSpace(modeStack.length + 1)} Getting first changeset ${csdetail.changesetId}`);
//                              }
//                             } else {
//                               csdetail = undefined;
//                         }
//                          break;
//                     } // end switch
//                 }
//             } else {
//                 logInfo("Mode != BODY");
//                 if (line.trim().length === 0) {
//                     // we have a blank line, we can't eval this
//                     output += "\n";
//             } else {
//                 if (((modeStack[modeStack.length - 1].Mode === Mode.WI) && (widetail === undefined)) ||
//                    ((modeStack[modeStack.length - 1].Mode === Mode.CS) && (csdetail === undefined))) {
//                     // # there is no data to expand
//                     output += emptySetText;
//                 } else {
//                     logInfo("Nothing to expand, just process the line");
//                     // nothing to expand just process the line
//                     var fixedline = fixline (line);
//                     var processedLine = eval(fixedline);
//                     var lines = processedLine.split("\r\n");
//                     for ( var i = 0; i < lines.length; i ++) {
//                        output += lines[i];
//                     }
//                 }
//                     // always add a line feed
//                 output += "\n";
//            }
//         }
//     }  // loop
//        logInfo( "Completed processing template");
//     } else {
//        logError( `Cannot load template file [${template}] or it is empty`);
//     }  // if no template

//     return output;
// }

// export function writeFile(filename: string, data: string) {
//      logInfo(`Writing output file ${filename}`);
//      fs.writeFile(filename, data);
// }

// // The release management API has a different URL
// function fixRmUrl(url: string ): string {
//      return url.replace(".visualstudio.com",  ".vsrm.visualstudio.com/defaultcollection");
// }

// const Mode = {
//     BODY : "BODY",
//     WI : "WI",
//     CS : "CS"
// };

// function getMode (line): string {
//      var mode = Mode.BODY;
//      if (line.trim() === "@@WILOOP@@") {
//          mode = Mode.WI;
//      }
//      if (line.trim() === "@@CSLOOP@@") {
//          mode = Mode.CS;
//      }
//      return mode;
// }

// function addStackItem (
//         items,
//         modeStack,
//         mode,
//         index
//     ) {
//     // Create a queue of the items
//     var queue = [];
//     // add each item to the queue if we have any
//     if (items) {
//         for (let item of items) {
//             queue.push(item);
//         }
//     }

//     logDebug (`${addSpace(modeStack.length + 1)} Added ${queue.length} items to queue for ${mode}`);
//     // place it on the stack with the blocks mode and start line index
//     modeStack.push({"Mode": mode, "BlockQueue": queue, "Index": index});
// }

// function addSpace (indent): string {
//     var size = 3;
//     var upperBound = size * indent;
//     var padding = "";
//     for (var i = 1 ; i < upperBound  ; i++) {
//         padding += " ";
//     }
//     return padding;
// }

// // Take a template line and convert it to something we can eval
// function fixline (line: string ): string {
//     // we can't use simple string replace as it only replaces the first instance
//     // could use the regex form but think this is easier to read in the future
//     return  "\"" + line.trim().split("${").join("\" + ").split("}").join(" + \"") + "\"";
// }

export interface SimpleArtifact {
    artifactAlias: string;
    buildDefinitionId: string;
    buildNumber: string;
    buildId: string;
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
import { Change } from "vso-node-api/interfaces/BuildInterfaces";
import { IGitApi } from "vso-node-api/GitApi";
import { GitCommit } from "vso-node-api/interfaces/GitInterfaces";
import { HttpClient } from "typed-rest-client/HttpClient";
import { WorkItem } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";

let agentApi = new AgentSpecificApi();

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
                "buildId": artifact.definitionReference.version.id
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
            agentApi.logInfo(`Expanding the truncated commit messages...`);
            for (var change of globalCommits) {
                if (change.messageTruncated) {
                    agentApi.logInfo(`Expanding commit [${change.id}]`);
                    let res: restm.IRestResponse<GitCommit> = await restClient.get<GitCommit>(change.location);

                    if (res.statusCode === 200) {
                        change.message = res.result.comment;
                        change.messageTruncated = false;
                    } else {
                        agentApi.logDebug(`Failed to get the full commit message for ${change.id}`);
                    }
                }
            }
            agentApi.logInfo(`Finished expanding.`);
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

export function processTemplate(template, workItems: WorkItem[], commits: Change[], releaseDetails: Release, emptySetText): string {

    var widetail = undefined;
    var csdetail = undefined;
    var lastBlockStartIndex;
    var output = "";

    if (template.length > 0) {
        agentApi.logInfo("Processing template");
        // create our work stack and initialise
        var modeStack = [];
        modeStack.push(Mode.BODY);

      // process each line
      for (var index = 0; index < template.length; index++) {
        agentApi.logInfo("Processing Line: " + (index + 1));
          var line = template[index];

          // get the line change mode if any
          var mode = getMode(line);

          if (mode !== Mode.BODY) {
              // is there a mode block change
              if (modeStack[modeStack.length - 1].Mode === mode) {
                  // this means we have reached the end of a block
                  // need to work out if there are more items to process
                  // or the end of the block
                  var queue = modeStack[modeStack.length - 1].BlockQueue;
                  if (queue.length > 0) {
                      // get the next item and initialise
                      // the variables exposed to the template
                      var item = queue.shift();
                      // reset the index to process the block
                      index = modeStack[modeStack.length - 1].Index;
                      switch (mode) {
                        case Mode.WI :
                            agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting next workitem ${item.id}`);
                            widetail = item;
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
                      mode = modeStack.pop().Mode;
                      agentApi.logDebug (`${addSpace(modeStack.length + 1)} Ending block ${mode}`);
                  }
              } else {
                  // this a new block to add the stack
                  // need to get the items to process and place them in a queue
                  agentApi.logDebug (`${addSpace(modeStack.length + 1)} Starting block ${mode}`);

                  // set the index to jump back to
                  lastBlockStartIndex = index;
                  switch (mode) {
                      case Mode.WI:
                        // store the block and load the first item
                        addStackItem (workItems, modeStack, mode, index);
                        if (modeStack[modeStack.length - 1].BlockQueue.length > 0) {
                            widetail = modeStack[modeStack.length - 1].BlockQueue.shift();
                            agentApi.logDebug (`${addSpace(modeStack.length + 1)} Getting first workitem ${widetail.id}`);
                        } else {
                            widetail = undefined;
                        }
                        break;
                      case Mode.CS:
                         // store the block and load the first item
                         addStackItem (commits, modeStack, mode, index);
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
                agentApi.logInfo("Mode != BODY");
                if (line.trim().length === 0) {
                    // we have a blank line, we can't eval this
                    output += "\n";
            } else {
                if (((modeStack[modeStack.length - 1].Mode === Mode.WI) && (widetail === undefined)) ||
                   ((modeStack[modeStack.length - 1].Mode === Mode.CS) && (csdetail === undefined))) {
                    // # there is no data to expand
                    output += emptySetText;
                } else {
                    agentApi.logInfo("Nothing to expand, just process the line");
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

const Mode = {
     BODY : "BODY",
     WI : "WI",
     CS : "CS"
};

function getMode (line): string {
     var mode = Mode.BODY;
     if (line.trim() === "@@WILOOP@@") {
         mode = Mode.WI;
     }
     if (line.trim() === "@@CSLOOP@@") {
         mode = Mode.CS;
     }
     return mode;
}

function addStackItem (
        items,
        modeStack,
        mode,
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

    agentApi.logDebug (`${addSpace(modeStack.length + 1)} Added ${queue.length} items to queue for ${mode}`);
    // place it on the stack with the blocks mode and start line index
    modeStack.push({"Mode": mode, "BlockQueue": queue, "Index": index});
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
function fixline (line: string ): string {
    // we can't use simple string replace as it only replaces the first instance
    // could use the regex form but think this is easier to read in the future
    return  "\"" + line.trim().split("${").join("\" + ").split("}").join(" + \"") + "\"";
}