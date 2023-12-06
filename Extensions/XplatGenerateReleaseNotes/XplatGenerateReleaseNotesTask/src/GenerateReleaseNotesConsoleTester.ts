import * as util from "./ReleaseNotesFunctions";
import fs = require("fs");
import { exit } from "process";

async function run(): Promise<number> {
  var promise = new Promise<number>(async (resolve, reject) => {

    try {
      console.log("Starting XplatGenerateReleaseNotes Local Tester");
      var argv = require("minimist")(process.argv.slice(2));
      var filename = argv["filename"];
      var oath = argv["oath"];
      var pat = argv["pat"];
      var gitHubPat = argv["githubpat"];
      var bitbucketUser = argv["bitbucketuser"];
      var bitbucketSecret = argv["bitbucketsecret"];
      var payloadFile = argv["payloadFile"];

      var showUsage = false;
      if (!filename || filename.length === 0) {
        showUsage = true;
      }

      // Removed since the proper behavior is if PAT is not provided to use pipeline token if you run the console tester in pipeline
      // if (!pat || pat.length === 0) {
      //   showUsage = true;
      // }

      if (showUsage) {
        console.error("USAGE: node .\\GenerateReleaseNotesConsoleTester.js --filename settings.json [--pat <Azure-DevOps-PAT>] [--oath <Azure-DevOps-Oath-Token>] --githubpat <Optional GitHub-PAT> --bitbucketuser <Optional Bitbucket User> --bitbucketsecret <Optional Bitbucket App Secret> --payloadFile <Optional JSON Payload File>");
      } else {
        console.log(`Command Line Arguments:`);
        console.log(`  --filename: ${filename}`);
        console.log(`  --oath: ${obfuscatePasswordForLog(oath)}`);
        console.log(`  --pat: ${obfuscatePasswordForLog(pat)}`);
        console.log(`  --githubpat: ${obfuscatePasswordForLog(gitHubPat)} (Optional)`);
        console.log(`  --bitbucketuser: ${obfuscatePasswordForLog(bitbucketUser)} (Optional)`);
        console.log(`  --bitbucketsecret: ${obfuscatePasswordForLog(bitbucketSecret)} (Optional)`);
        console.log(`  --payloadFile: ${payloadFile} (Optional)`);

        if (fs.existsSync(filename)) {
          console.log(`Loading settings from ${filename}`);
          let jsonData = fs.readFileSync(filename);
          let settings = JSON.parse(jsonData.toString());

          let tpcUri: string = settings.TeamFoundationCollectionUri;
          let teamProject: string = settings.TeamProject;
          var templateLocation: string = settings.templateLocation || "File";
          var templateFile: string = settings.templatefile || "";
          var inlineTemplate: string = settings.inlinetemplate || "";
          var outputFile: string = settings.outputfile || "";
          var outputVariableName: string = settings.outputVariableName || "";
          var showOnlyPrimary: boolean = getBoolean(settings.showOnlyPrimary, false);
          var replaceFile: boolean = getBoolean(settings.replaceFile, true);
          var appendToFile: boolean = getBoolean(settings.appendToFile, true);
          var getParentsAndChildren: boolean = getBoolean(settings.getParentsAndChildren, false);
          var getAllParents: boolean = getBoolean(settings.getAllParents, false);
          var searchCrossProjectForPRs: boolean = getBoolean(settings.searchCrossProjectForPRs, false);

          var stopOnRedeploy: boolean = getBoolean(settings.stopOnRedeploy, false);
          var sortWi: boolean = getBoolean(settings.SortWi, false);
          var sortCS: boolean = getBoolean(settings.SortCS, false);
          var customHandlebarsExtensionCodeAsFile: string = settings.customHandlebarsExtensionCodeAsFile || "";
          var customHandlebarsExtensionCode: string = settings.customHandlebarsExtensionCode || "";
          var customHandlebarsExtensionFile: string = settings.customHandlebarsExtensionFile || "";
          var customHandlebarsExtensionFolder: string = settings.customHandlebarsExtensionFolder || "";
          var buildId: number = settings.buildId;  // we don't parse here as is done in main function
          var releaseId: number = settings.releaseId; // we don't parse here as is done in main function
          var releaseDefinitionId: number = settings.releaseDefinitionId; // we don't parse here as is done in main function
          var overrideActiveBuildReleaseId: string = settings.overrideActiveBuildReleaseId || "";
          var overrideStageName: string = settings.overrideStageName || "_default";  // simulates the default behaviour of the task
          var environmentName: string = settings.environmentName || "";
          var Fix349: string = settings.Fix349 || "true";  // this has to be string not a bool
          var dumpPayloadToConsole: boolean = getBoolean(settings.dumpPayloadToConsole, false);
          var dumpPayloadToFile: boolean = getBoolean(settings.dumpPayloadToFile, false);
          var dumpPayloadFileName: string = settings.dumpPayloadFileName || "payload.json";
          var checkStage: boolean = getBoolean(settings.checkStage, false);
          var tags: string = settings.tags || "";
          var overrideBuildReleaseId: string = settings.overrideBuildReleaseId;
          var getIndirectPullRequests: boolean = getBoolean(settings.getIndirectPullRequests, false);

          var maxRetries: number = parseInt(settings.maxRetries || "20");
          var pauseTime: number = parseInt(settings.pauseTime || "5000"); // no longer used
          var stopOnError: boolean = getBoolean(settings.stopOnError, false);
          var considerPartiallySuccessfulReleases: boolean = getBoolean(settings.considerPartiallySuccessfulReleases, false);
          var checkForManuallyLinkedWI: boolean = getBoolean(settings.checkForManuallyLinkedWI, false);
          var wiqlWhereClause: string = settings.wiqlWhereClause || "";
          var getPRDetails: boolean = getBoolean(settings.getPRDetails, true);
          var getTestedBy: boolean = getBoolean(settings.getTestedBy, true);
          var wiqlFromTarget: string = settings.wiqlFromTarget || "WorkItems";
          var wiqlSharedQueryName: string = settings.wiqlSharedQueryName || "";

          if (payloadFile && payloadFile.length > 0 && fs.existsSync(payloadFile)) {
            console.log(`Running the tester against a local payload JSON file`);
            var payload = JSON.parse(fs.readFileSync(payloadFile).toString());
            var template = util.getTemplate(templateLocation, templateFile, inlineTemplate);

            if ((template) && (template.length > 0)) {
              var outputString = util.processTemplate(
                template,
                payload.workItems ? payload.workItems : [],
                payload.commits ? payload.commits : [],
                payload.buildDetails,
                payload.releaseDetails,
                payload.compareReleaseDetails,
                customHandlebarsExtensionCodeAsFile,
                customHandlebarsExtensionCode,
                customHandlebarsExtensionFile,
                customHandlebarsExtensionFolder,
                payload.pullRequests ? payload.pullRequests : [],
                payload.globalBuilds ? payload.globalBuilds : [],
                payload.globalTests ? payload.globalTests : [],
                payload.releaseTests ? payload.releaseTests : [],
                payload.relatedWorkItems ? payload.relatedWorkItems : [],
                payload.compareBuildDetails,
                payload.currentStage,
                payload.inDirectlyAssociatedPullRequests ? payload.inDirectlyAssociatedPullRequests : [],
                payload.globalManualTests ? payload.globalManualTests : [],
                payload.globalManualTestConfigurations ? payload.globalManualTestConfigurations : [],
                false,
                payload.globalConsumedArtifacts ? payload.globalConsumedArtifacts : [],
                payload.queryWorkItems ? payload.queryWorkItems : [],
                payload.testedByWorkItems ? payload.testedByWorkItems : [],
                payload.publishedArtifacts ? payload.publishedArtifacts : []);
              util.writeFile(outputFile, outputString, replaceFile, appendToFile);

            } else {
              console.error("Template is empty");
            }
          } else {

            console.log(`Running the tester against the Azure DevOps API`);

            var returnCode = await util.generateReleaseNotes(
              oath,
              pat,
              tpcUri,
              teamProject,
              buildId,
              releaseId,
              releaseDefinitionId,
              overrideActiveBuildReleaseId,
              overrideStageName,
              environmentName,
              Fix349,
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
              customHandlebarsExtensionCodeAsFile,
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
              wiqlFromTarget,
              wiqlSharedQueryName);
          }

        } else {
          console.log(`Cannot fine settings file ${filename}`);
        }
      }

    } catch (err) {

      console.error(err);
      reject(err);
    }
    resolve(returnCode);
  });
  return promise;
}

function getBoolean(value, defaultValue): boolean {
  if (value === undefined || value === null) {
    return defaultValue;
  } else {
    switch (value) {
      case true:
      case "true":
      case "True":
      case "TRUE":
      case "1":
      case "on":
      case "yes":
        return true;
      case false:
      case "false":
      case "False":
      case "FALSE":
      case 0:
      case "0":
      case "off":
      case "no":
        return false;
      default:
        return defaultValue;
    }
  }
}

function obfuscatePasswordForLog(value: string, charToShow = 4, charToUse = "*") {
  var returnValue = "";
  if (value && value.length > 0) {
    returnValue = `${new Array(value.length - charToShow + 1).join(charToUse)}${value.substring(value.length - charToShow)}`;
  }
  return returnValue;
}

run()
  .then((result) => {
    console.log("Tool exited");
  })
  .catch((err) => {
    console.error(err);
  });
