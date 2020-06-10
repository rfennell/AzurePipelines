import tl = require("azure-pipelines-task-lib/task");
import { AgentSpecificApi } from "./agentSpecific";
import * as util from "./ReleaseNotesFunctions";

let agentApi = new AgentSpecificApi();

async function run(): Promise<number>  {
    var promise = new Promise<number>(async (resolve, reject) => {

        try {
            agentApi.logDebug("Starting Tag XplatGenerateReleaseNotes task");

            let tpcUri = tl.getVariable("System.TeamFoundationCollectionUri");
            let teamProject = tl.getVariable("System.TeamProject");
            var templateLocation = tl.getInput("templateLocation", true);
            var templateFile = tl.getInput("templatefile");
            var inlineTemplate = tl.getInput("inlinetemplate");
            var outputFile = tl.getInput("outputfile", true);
            var outputVariableName = tl.getInput("outputVariableName");
            var emptyDataset = tl.getInput("emptySetText");
            var delimiter = tl.getInput("delimiter");
            var anyFieldContent = tl.getInput("anyFieldContent");
            var showOnlyPrimary = tl.getBoolInput("showOnlyPrimary");
            var replaceFile = tl.getBoolInput("replaceFile");
            var appendToFile = tl.getBoolInput("appendToFile");
            var getParentsAndChildren = tl.getBoolInput("getParentsAndChildren");
            var searchCrossProjectForPRs = tl.getBoolInput("searchCrossProjectForPRs");
            var fieldEquality = tl.getInput("fieldEquality");
            var overrideStageName = tl.getInput("overrideStageName");
            var stopOnRedeploy = tl.getBoolInput("stopOnRedeploy");
            var sortWi = tl.getBoolInput("SortWi");
            var customHandlebarsExtensionCode = tl.getInput("customHandlebarsExtensionCode");
            var customHandlebarsExtensionFile = tl.getInput("customHandlebarsExtensionFile");
            var customHandlebarsExtensionFolder = tl.getInput("customHandlebarsExtensionFolder");
            var gitHubPat = tl.getInput("gitHubPat");
            var dumpPayloadToFile = tl.getBoolInput("dumpPayloadToFile");
            var dumpPayloadToConsole = tl.getBoolInput("dumpPayloadToConsole");
            var dumpPayloadFileName = tl.getInput("dumpPayloadFileName");

        var returnCode = await util.generateReleaseNotes(
            "",
            tpcUri,
            teamProject,
            parseInt(tl.getVariable("Build.BuildId")),
            parseInt(tl.getVariable("Release.ReleaseId")),
            parseInt(tl.getVariable("Release.DefinitionId")),
            overrideStageName,
            tl.getVariable("Release_EnvironmentName"),
            tl.getVariable("ReleaseNotes.Fix349"),
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

        } catch (err) {

            agentApi.logError(err);
            reject(err);
        }
        resolve (returnCode);
    });
    return promise;
}

run()
    .then((result) => {
        if (result === -1) {
            tl.setResult(tl.TaskResult.SucceededWithIssues, "Skipped release notes generation as redeploy");
        } else {
            tl.setResult(tl.TaskResult.Succeeded, "");
        }
    })
    .catch((err) => {
        agentApi.publishEvent("reliability", { issueType: "error", errorMessage: JSON.stringify(err, Object.getOwnPropertyNames(err)) });
        tl.setResult(tl.TaskResult.Failed, err);
    });
