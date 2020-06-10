import * as util from "../ReleaseNotesFunctions";
import fs  = require("fs");



async function run(): Promise<number>  {
    var promise = new Promise<number>(async (resolve, reject) => {

        try {
            console.log("Starting Tag XplatGenerateReleaseNotes Local Tester");
            var args = process.argv;
            if (args.length < 4 || args.length > 5) 
            {
                console.error("USAGE: node .\GenerateReleaseNotesConsoleTester.js settings.json <Azure-DevOps-PAT> <Optional GitHub-PAT>")
            } else  {
                var filename = args[2];
                var pat = args[3];
                var gitHubPat = args[4];

                if (fs.existsSync(filename)) {
                    console.log(`Loading settings from ${filename}`);
                    let jsonData = fs.readFileSync(filename);
                    let settings = JSON.parse(jsonData.toString());

                    let tpcUri = settings.TeamFoundationCollectionUri;
                    let teamProject = settings.TeamProject;
                    var templateLocation = settings.templateLocation;
                    var templateFile = settings.templatefile;
                    var inlineTemplate = settings.inlinetemplate;
                    var outputFile = settings.outputfile;
                    var outputVariableName = settings.outputVariableName;
                    var emptyDataset = settings.emptySetText;
                    var delimiter = settings.delimiter;
                    var anyFieldContent = settings.anyFieldContent;
                    var showOnlyPrimary = getBoolean(settings.showOnlyPrimary);
                    var replaceFile = getBoolean(settings.replaceFile);
                    var appendToFile = getBoolean(settings.appendToFile);
                    var getParentsAndChildren = getBoolean(settings.getParentsAndChildren);
                    var searchCrossProjectForPRs = getBoolean(settings.searchCrossProjectForPRs);
                    var fieldEquality = settings.fieldEquality;

                    var stopOnRedeploy = settings.stopOnRedeploy;
                    var sortWi = getBoolean(settings.SortWi);
                    var customHandlebarsExtensionCode = settings.customHandlebarsExtensionCode;
                    var customHandlebarsExtensionFile = settings.customHandlebarsExtensionFile;
                    var customHandlebarsExtensionFolder = settings.customHandlebarsExtensionFolder;
                    var buildId = settings.buildId;
                    var releaseId = settings.releaseId;
                    var releaseDefinitionId = settings.releaseDefinitionId;
                    var overrideStageName = settings.overrideStageName;
                    var environmentName = settings.environmentName;
                    var Fix349 = settings.Fix349;  // this has to be string not a bool
                    var dumpPayloadToConsole = getBoolean(settings.dumpPayloadToConsole);
                    var dumpPayloadToFile = getBoolean(settings.dumpPayloadToFile);
                    var dumpPayloadFileName = settings.dumpPayloadFileName;

                    var returnCode = await util.generateReleaseNotes(
                        pat,
                        tpcUri,
                        teamProject,
                        buildId,
                        releaseId,
                        releaseDefinitionId,
                        overrideStageName,
                        environmentName,
                        Fix349,
                        templateLocation,
                        templateFile,
                        inlineTemplate,
                        outputFile,
                        outputVariableName,
                        emptyDataset,
                        delimiter,
                        anyFieldContent,
                        showOnlyPrimary,
                        replaceFile,
                        appendToFile,
                        getParentsAndChildren,
                        searchCrossProjectForPRs,
                        fieldEquality,
                        stopOnRedeploy,
                        sortWi,
                        customHandlebarsExtensionCode,
                        customHandlebarsExtensionFile,
                        customHandlebarsExtensionFolder,
                        gitHubPat,
                        dumpPayloadToConsole,
                        dumpPayloadToFile,
                        dumpPayloadFileName);
                } else {
                    console.log(`Cannot fine settings file ${filename}`);
                }
            }

        } catch (err) {

            console.error(err);
            reject(err);
        }
        resolve (returnCode);
    });
    return promise;
}

function getBoolean (value){
    switch( value) {
         case true:
         case "true":
         case 1:
         case "1":
         case "on":
         case "yes":
             return true;
         default:
             return false;
     }
 }

run()
    .then((result) => {
        console.log("Tool exited");
    })
    .catch((err) => {
        console.error(err);
    });
