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

getRelease(instance, teamproject, encodedPat, currentReleaseId, function(details)
{

   // get the current release details first
    var currentReleaseDetails = details;
    getBuild(instance, teamproject, encodedPat, getPrimaryBuildIdFromRelease(currentReleaseDetails), function(details)
    {
        var currentBuildDetails =  details;

        // see if we are overriding the stage we are interested in?
        if (overrideStage === null)
        {
            overrideStage = currentStage;
        }
        
        getPastSuccessfulRelease(instance, teamproject, encodedPat, currentReleaseDetails, overrideStage,  function(details)
        {
            var compareReleaseDetails = details;
            getBuild(instance, teamproject, encodedPat, getPrimaryBuildIdFromRelease(compareReleaseDetails), function(details)
            {
                var compareBuildDetails =  details;
         
                getWorkItemBetweenReleases(instance, teamproject, encodedPat, currentReleaseId, compareReleaseDetails.id, function (workItems)
                {
                    // get list of work item ids
                    var ids = workItems.map(w => w.id);
                    // and expand the details
                    getWorkItems(instance, encodedPat, ids.join(), function (details)
                    {
                        var workItems = details;

                        getCommitsBetweenCommitIds (
                            instance, 
                            teamproject, 
                            encodedPat, 
                            currentBuildDetails.repository.type,
                            currentBuildDetails.definition.id, 
                            currentBuildDetails.repository.id, 
                            currentBuildDetails.sourceVersion, 
                            compareBuildDetails.sourceVersion, function (commits)
                        {
                            var template = getTemplate(templateLocation,templateFile,inlineTemplate);

                            var outputString = processTemplate(template, workItems, commits, currentReleaseDetails, compareReleaseDetails, emptyDataset);
                            writeFile(outputfile, outputString);
                            writeVariable(outputVariableName,outputString.toString());
                           
                        });    
                    });
                });
            });
        });
    });
});

