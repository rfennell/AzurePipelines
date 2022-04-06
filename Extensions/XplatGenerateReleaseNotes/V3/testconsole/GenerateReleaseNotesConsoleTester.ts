import * as util from "../ReleaseNotesFunctions";
import fs = require("fs");
import { exit } from "process";

async function run(): Promise<number> {
  var promise = new Promise<number>(async (resolve, reject) => {

    try {
      console.log("Starting Tag XplatGenerateReleaseNotes Local Tester");
      var argv = require("minimist")(process.argv.slice(2));
      var filename = argv["filename"];
      var pat = argv["pat"];
      var gitHubPat = argv["githubpat"];
      var bitbucketUser = argv["bitbucketuser"];
      var bitbucketSecret = argv["bitbucketsecret"];
      var payloadFile = argv["payloadfile"];

      var showUsage = false;
      if (!filename || filename.length === 0) {
        showUsage = true;
      }

      if (!pat || pat.length === 0) {
        showUsage = true;
      }

      if (showUsage) {
        console.error("USAGE: node GenerateReleaseNotesConsoleTester.js --filename settings.json --pat <Azure-DevOps-PAT> --githubpat <Optional GitHub-PAT> --bitbucketuser <Optional Bitbucket User> --bitbucketsecret <Optional Bitbucket App Secret> --payloadFile <Optional JSON Payload File>");
      } else {
        console.log(`Command Line Arguments:`);
        console.log(`  --filename: ${filename}`);
        console.log(`  --pat: ${obfuscatePasswordForLog(pat)}`);
        console.log(`  --githubpat: ${obfuscatePasswordForLog(gitHubPat)} (Optional)`);
        console.log(`  --bitbucketuser: ${obfuscatePasswordForLog(bitbucketUser)} (Optional)`);
        console.log(`  --bitbucketsecret: ${obfuscatePasswordForLog(bitbucketSecret)} (Optional)`);
        console.log(`  --payloadFile: ${payloadFile} (Optional)`);

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
          var showOnlyPrimary = getBoolean(settings.showOnlyPrimary);
          var replaceFile = getBoolean(settings.replaceFile);
          var appendToFile = getBoolean(settings.appendToFile);
          var getParentsAndChildren = getBoolean(settings.getParentsAndChildren);
          var getAllParents = getBoolean(settings.getAllParents);
          var searchCrossProjectForPRs = getBoolean(settings.searchCrossProjectForPRs);

          var stopOnRedeploy = settings.stopOnRedeploy;
          var sortWi = getBoolean(settings.SortWi);
          var sortCS = getBoolean(settings.SortCS);
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
          var checkStage = getBoolean(settings.checkStage);
          var tags = settings.tags;
          var overrideBuildReleaseId = settings.overrideBuildReleaseId;
          var getIndirectPullRequests = getBoolean(settings.getIndirectPullRequests);

          var maxRetries = parseInt(settings.maxRetries);
          var pauseTime = parseInt(settings.pauseTime); // no longer used
          var stopOnError = getBoolean(settings.stopOnError);
          var considerPartiallySuccessfulReleases = getBoolean(settings.considerPartiallySuccessfulReleases);
          var checkForManuallyLinkedWI = getBoolean(settings.checkForManuallyLinkedWI);
          var wiqlWhereClause = settings.wiqlWhereClause;
          var getPRDetails = getBoolean(settings.getPRDetails);
          var getTestedBy = getBoolean(settings.getTestedBy);
          var wiqlFromTarget = settings.wiqlFromTarget;

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
                payload.testedByWorkItems ? payload.testedByWorkItems : []);
              util.writeFile(outputFile, outputString, replaceFile, appendToFile);

            } else {
              console.error("Template is empty");
            }
          } else {

            console.log(`Running the tester against the Azure DevOps API`);

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
              wiqlFromTarget);
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

function getBoolean(value) {
  switch (value) {
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
