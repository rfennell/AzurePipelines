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
if (overrideStage === null)
{
    overrideStage = currentStage;
}

getRelease(instance, teamproject, encodedPat, currentReleaseId, function(details)
{
    var currentReleaseDetails = details;
    getPastSuccessfulRelease(instance, teamproject, encodedPat, currentReleaseDetails, overrideStage,  function(details)
    {
        var pastSuccessfulRelease = details;

        var template = getTemplate(templateLocation,templateFile,inlineTemplate);
        var globalWorkitems = [];
        var globalCommits = [];

        // loop through each build current release
        details.artifacts.forEach(artifact => {
            
            getBuild(instance, teamproject, encodedPat, artifact.definitionReference.version.id, function(details)
            {
                var currentReleaseBuild = details;

                // Get the build from the past successful release
                var pastSuccessfulMatchingBuild = pastSuccessfulRelease.artifacts.find(item => item.definitionReference.definition == artifact.definitionReference.version.id);

                if (pastSuccessfulMatchingBuild != null){
                    // We have a matching build
                    getBuild(instance, teamproject, encodedPat, pastSuccessfulMatchingBuild.definitionReference.version.id, function(details)
                    {
                        var pastSuccessfulMatchingBuild = details
                        getWorkItemBetweenReleases(instance, teamproject, encodedPat, currentReleaseId, pastSuccessfulRelease.id, function (workItems)
                        {
                            var ids = [];
                            if (workItems){
                                // get list of work item ids
                                ids = workItems.map(w => w.id);
                            }

                            // and expand the details
                            getWorkItems(instance, encodedPat, ids.join(), function (details)
                            {
                                var workItems = details;

                                getCommitsBetweenCommitIds (
                                    instance, 
                                    teamproject, 
                                    encodedPat, 
                                    currentReleaseBuild.repository.type,
                                    currentReleaseBuild.definition.id, 
                                    currentReleaseBuild.repository.id, 
                                    currentReleaseBuild.sourceVersion, 
                                    pastSuccessfulMatchingBuild.sourceVersion, function (commits)
                                {                                   
                                    globalWorkitems += workItems;
                                    globalCommits += commits;
                                   
                                
                                });   

                            });
                        });
                    });
                }else{
                    console.log(`Failed to locate matching artifact with build definition id [${artifact.definitionReference.version.id}] in release [${pastSuccessfulRelease.id}]`)
                }
            });
        });
        var outputString = processTemplate(template, globalWorkitems, globalCommits, currentReleaseDetails, pastSuccessfulRelease, emptyDataset);
        writeFile(outputfile, outputString);
        writeVariable(outputVariableName,outputString.toString());
    });
});



