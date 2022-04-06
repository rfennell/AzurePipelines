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
            var showOnlyPrimary = tl.getBoolInput("showOnlyPrimary");
            var replaceFile = tl.getBoolInput("replaceFile");
            var appendToFile = tl.getBoolInput("appendToFile");
            var getParentsAndChildren = tl.getBoolInput("getParentsAndChildren");
            var searchCrossProjectForPRs = tl.getBoolInput("searchCrossProjectForPRs");
            var overrideStageName = tl.getInput("overrideStageName");
            var stopOnRedeploy = tl.getBoolInput("stopOnRedeploy");
            var sortWi = tl.getBoolInput("SortWi");
            var sortCS = tl.getBoolInput("SortCS");
            var customHandlebarsExtensionCode = tl.getInput("customHandlebarsExtensionCode");
            var customHandlebarsExtensionFile = tl.getInput("customHandlebarsExtensionFile");
            var customHandlebarsExtensionFolder = tl.getInput("customHandlebarsExtensionFolder");
            var gitHubPat = tl.getInput("gitHubPat");
            var bitbucketSecret = tl.getInput("bitbucketSecret");
            var bitbucketUser = tl.getInput("bitbucketUser");
            var dumpPayloadToFile = tl.getBoolInput("dumpPayloadToFile");
            var dumpPayloadToConsole = tl.getBoolInput("dumpPayloadToConsole");
            var dumpPayloadFileName = tl.getInput("dumpPayloadFileName");
            var checkStage = tl.getBoolInput("checkStage");
            var getAllParents = tl.getBoolInput("getAllParents");
            var tags = tl.getInput("tags");
            var overridePat = tl.getInput("overridePat");
            var overrideBuildReleaseId = tl.getInput("overrideBuildReleaseId");
            var getIndirectPullRequests = tl.getBoolInput("getIndirectPullRequests");
            var stopOnError = tl.getBoolInput("stopOnError");
            var considerPartiallySuccessfulReleases = tl.getBoolInput("considerPartiallySuccessfulReleases");
            var checkForManuallyLinkedWI = tl.getBoolInput("checkForManuallyLinkedWI");
            var wiqlWhereClause = tl.getInput("wiqlWhereClause");
            var getPRDetails = tl.getBoolInput("getPRDetails");
            var getTestedBy = tl.getBoolInput("getTestedBy");
            var wiqlFromTarget = tl.getInput("wiqlFromTarget");

            var maxRetries = parseInt(tl.getInput("maxRetries"));

            var returnCode = await util.generateReleaseNotes(
                overridePat,
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
                sortWi,
                showOnlyPrimary,
                replaceFile,
                appendToFile,
                getParentsAndChildren,
                searchCrossProjectForPRs,
                stopOnRedeploy,
                customHandlebarsExtensionCode,
                customHandlebarsExtensionFile,
                customHandlebarsExtensionFolder,
                gitHubPat,
                bitbucketUser,
                bitbucketSecret,
                dumpPayloadToConsole,
                dumpPayloadToFile,
                dumpPayloadFileName,
                checkStage,
                getAllParents,
                tags,
                overrideBuildReleaseId,
                getIndirectPullRequests,
                maxRetries,
                stopOnError,
                considerPartiallySuccessfulReleases,
                sortCS,
                checkForManuallyLinkedWI,
                wiqlWhereClause,
                getPRDetails,
                getTestedBy,
                wiqlFromTarget
                );

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
            tl.setResult(tl.TaskResult.SucceededWithIssues, "Release notes generation had an issue and was only partially successful");
        } else {
            tl.setResult(tl.TaskResult.Succeeded, "");
        }
    })
    .catch((err) => {
        agentApi.publishEvent("reliability", { issueType: "error", errorMessage: JSON.stringify(err, Object.getOwnPropertyNames(err)) });
        tl.setResult(tl.TaskResult.Failed, err);
    });
