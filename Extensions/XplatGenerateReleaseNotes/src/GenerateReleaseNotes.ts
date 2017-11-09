import tl = require("vsts-task-lib/task");

import { encodePat,
         getRelease,
         getWorkItemBetweenReleases,
         getWorkItems,
         getTemplate,
         processTemplate,
         writeFile,
         getPrimaryBuildIdFromRelease,
         getBuild,
         getCommitsBetweenCommitIds,
         getPastSuccessfulRelease
 }  from "./ReleaseNotesFunctions";

import { writeVariable,
         getSystemAccessToken
 }  from "./agentSpecific";

var pat = getSystemAccessToken();
var encodedPat = encodePat(pat);
var teamproject = process.env.SYSTEM_TEAMPROJECT;
var currentReleaseId = process.env.RELEASE_RELEASEID;
var instance = process.env.SYSTEM_TEAMFOUNDATIONCOLLECTIONURI;
var emptyDataset = tl.getInput("emptySetText");
var currentStage = process.env.RELEASE_ENVIRONMENTNAME;
var templateLocation = tl.getInput("templateLocation");
var templateFile = tl.getInput("templatefile");
var inlineTemplate = tl.getInput("inlinetemplate");
var outputfile = tl.getInput("outputfile");
var outputVariableName = tl.getInput("outputVariableName");

var overrideStage = tl.getInput("overrideStageName");

console.log(`Variable: Teamproject [${teamproject}]`);
console.log(`Variable: CurrentReleaseId [${currentReleaseId}]`);
console.log(`Variable: VSTS Instance [${instance}]`);
console.log(`Variable: EmptyDataset [${emptyDataset}]`);
console.log(`Variable: Current Environment Stage [${currentStage}]`);
console.log(`Variable: TemplateLocation [${templateLocation}]`);
console.log(`Variable: TemplateFile [${templateFile}]`);
console.log(`Variable: InlineTemplate [${inlineTemplate}]`);
console.log(`Variable: Outputfile [${outputfile}]`);
console.log(`Variable: OutputVariableName [${outputVariableName}]`);
console.log(`Variable: OverrideStage [${overrideStage}]`);

// see if we are overriding the stage we are interested in?
if (overrideStage === null) {
    overrideStage = currentStage;
}

async function run() {

    var template = getTemplate (templateLocation, templateFile, inlineTemplate);
    var globalWorkitems = [];
    var globalCommits = [];

    var currentReleaseDetails = await getRelease(instance, teamproject, encodedPat, currentReleaseId);

    var pastSuccessfulRelease = await getPastSuccessfulRelease(instance, teamproject, encodedPat, currentReleaseDetails, overrideStage);

    console.log(`Found ${currentReleaseDetails.artifacts.length + 1} artifacts in this release`);
    for (let artifact of currentReleaseDetails.artifacts) {
        console.log(`Looking at artifact [${artifact.alias}]`);
        console.log(`Getting build associated with artifact. Build Id [${artifact.definitionReference.version.id}]`);

        var currentReleaseBuild = await getBuild(instance, teamproject, encodedPat, artifact.definitionReference.version.id);

        console.log(`Looking for a matching artifact in the last successful release to ${overrideStage}`);
        // Get the build from the past successful release
        var pastSuccessfulMatchingArtifact = pastSuccessfulRelease.artifacts.find(item => item.definitionReference.definition.id === artifact.definitionReference.definition.id);

        if (pastSuccessfulMatchingArtifact != null) {
            console.log(`Located matching artifact. Alias: ${pastSuccessfulMatchingArtifact.alias}.`);

            // We have a matching build
            var pastSuccessfulMatchingBuild = await getBuild(instance, teamproject, encodedPat, pastSuccessfulMatchingArtifact.definitionReference.version.id);

            console.log(`Getting work items between release [${currentReleaseId}] and [${pastSuccessfulRelease.id}]`);

            var workItems = await getWorkItemBetweenReleases(instance, teamproject, encodedPat, currentReleaseId, pastSuccessfulRelease.id);
            var ids = [];
                if (workItems) {
                // get list of work item ids
                ids = workItems.map(w => w.id);
            }

            console.log(`Work items found: ${ids.length}`);

            // and expand the details
            var workItemDetails = await getWorkItems(instance, encodedPat, ids.join());
            // using the promise model we end up returns a null, this gets added to array, so we check for null here
            if (workItemDetails !== null) {
                globalWorkitems = globalWorkitems.concat(workItemDetails);
            }

            console.log(`Getting commits between [${currentReleaseBuild.sourceVersion}] and [${pastSuccessfulMatchingBuild.sourceVersion}].`);
            var commits: Array<any> = await getCommitsBetweenCommitIds (
                instance,
                teamproject,
                encodedPat,
                currentReleaseBuild.repository.type,
                currentReleaseBuild.definition.id,
                currentReleaseBuild.repository.id,
                currentReleaseBuild.sourceVersion,
                pastSuccessfulMatchingBuild.sourceVersion);

            console.log(`Commits found: ${commits.length}`);

            globalCommits = globalCommits.concat(commits);

        }

    }
    console.log(`Total commits found: ${globalCommits.length}`);
    console.log(`Total workitems found: ${globalWorkitems.length}`);
    var outputString = processTemplate(template, globalWorkitems, globalCommits, currentReleaseDetails, pastSuccessfulRelease, emptyDataset);
    writeFile(outputfile, outputString);
    writeVariable(outputVariableName, outputString.toString());
}

run();