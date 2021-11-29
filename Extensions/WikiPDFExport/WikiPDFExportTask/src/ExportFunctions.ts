import * as process from "process";
import { exec } from "child_process";
import * as fs from "fs";
import * as path from "path";
import {
    CloneWikiRepo,
    GetTrimmedUrl,
    GetProtocol
    } from "./GitWikiFunctions";
import {
    logInfo,
    logError,
    logWarning,
    getSystemAccessToken
    }  from "./agentSpecific";
import { filePathSupplied } from "azure-pipelines-task-lib";

async function DownloadGitHubArtifact(
    user,
    repo,
    folder,
    usePreRelease,
    artifactName,
    logInfo,
    logError) {

    var downloadRelease = require("download-github-release");
    logInfo(`Starting download ${artifactName} to ${folder}`);
    await downloadRelease(
        user,
        repo,
        folder,
        function filterRelease(release) {
            // Filter out prereleases.
            return release.prerelease === usePreRelease;
        },
        function filterAsset(asset) {
            // Select assets that contain the string .
            return (asset.name === artifactName);
        },
        false)
    .then(function() {
        logInfo("Download done");
    })
    .catch(function(err) {
        logError(err.message);
    });
}

export async function ExportPDF(
    command,
    wikiRootPath,
    singleFile,
    outputFile,
    extraParams,
    logInfo,
    logError) {

        if (command.length > 0) {
            if (!fs.existsSync(`${command}`)) {
                logError(`Cannot find ${command}`);
                return;
            }
        }

        // add quotes in case of spaces
        command = `"${command}"`;

        var args = "";
        if (wikiRootPath.length > 0) {
            if (!fs.existsSync(`${wikiRootPath}`)) {
                logError(`Cannot find wiki folder ${wikiRootPath}`);
                return;
            } else {
                args += ` -p "${wikiRootPath}"`;
            }
        }

        if (singleFile.length > 0) {
            if (!fs.existsSync(`${singleFile}`)) {
                logError(`Cannot find the requested file ${singleFile} to export`);
                return;
            } else {
                args += ` -s "${singleFile}"`;
            }
        } else {
            if (!fs.existsSync(`${wikiRootPath}/.order`)) {
                logInfo(`No filename specified and cannot find the .order file in the root of the wiki, the exported PDF will therefore be empty`);
            }
        }

        if (outputFile.length > 0) {
            args += ` -o "${outputFile}"`;
        } else {
            logError("No output file name provided");
            return;
        }

        if (extraParams && extraParams.length > 0) {
            logInfo("Adding extra parameters to the command line");
            args += ` ${extraParams}`;
        }

        if (!args.includes("-v")) {
            logInfo("Adding the verbose flag to increase logging");
            args += ` -v`;
        }

    var folder = path.dirname(outputFile);
    if (!fs.existsSync(folder)) {
        logInfo(`Creating folder ${folder}`);
        fs.mkdirSync(folder, { recursive: true });
    }
    logInfo(`Changing folder to ${wikiRootPath}`);
    process.chdir(wikiRootPath);

    command += ` ${args}`;

    logInfo(`Using command '${command}'`);

    exec(command, function (error, stdout, stderr) {
        logInfo(stdout);
        logInfo(stderr);
        if (error !== null) {
            logError(error);
        }
    });
}

export async function GetExePath (
    overrideExePath,
    workingFolder,
    usePreRelease,
    os: string
) {
    if (overrideExePath &&  overrideExePath.length > 0) {
        if (fs.existsSync(overrideExePath)) {
            logInfo(`Using the overrideExePath`);
            return `${overrideExePath}`;
        } else {
            logWarning(`Attempting to use the overrideExePath of ${overrideExePath} but cannot find the file`);
            return "";
        }
    } else {
        var artifactName = "azuredevops-export-wiki";
        if (os === "Windows_NT") {
            artifactName = "azuredevops-export-wiki.exe";
        } else if (os === "Darwin") {
            artifactName = "azuredevops-export-wiki-osx";
        }

        await DownloadGitHubArtifact(
            "MaxMelcher",
            "AzureDevOps.WikiPDFExport",
            workingFolder,
            usePreRelease,
            artifactName,
            logInfo,
            logError);

        var exeCmd = path.join(workingFolder, artifactName);

        // `Pause to avoid 'The process cannot access the file because it is being used by another process.' error`
        // It seems that even though we wait for the download the file is not available to run for a short period.
        // This is a nasty solution but appears to work
        await new Promise(resolve => setTimeout(resolve, 5000));

        logInfo(`Downloaded executable ${exeCmd}`);

        if (os !== "Windows_NT") {
            logInfo(`Set execute permission on executable ${exeCmd}`);
            fs.chmodSync(exeCmd, "777");
        }

        return `${exeCmd}`;
    }
}

export async function ExportRun (
    exeCmd,
    cloneRepo,
    localpath,
    singleFile,
    outputFile,
    extraParams,
    useAgentToken,
    repo,
    user,
    password,
    injectExtraHeader,
    branch,
    rootExportPath
 ) {

    if (fs.existsSync(exeCmd)) {
        logInfo(`Using the EXE path of '${exeCmd}' for AzureDevOps.WikiPDFExport`);
    } else {
        logError(`Cannot find the AzureDevOps.WikiPDFExport tool in '${exeCmd}'`);
        return;
    }

    if (cloneRepo) {
         console.log(`Cloning Repo`);
         if (useAgentToken === true) {
             console.log(`Using OAUTH Agent Token, overriding username and password`);
             user = "buildagent";
             password = getSystemAccessToken();
         }

         var protocol = GetProtocol(repo, logInfo);
         repo = GetTrimmedUrl(repo, logInfo);

         await CloneWikiRepo(protocol, repo, localpath, user, password, logInfo, logError, injectExtraHeader, branch);
     }

     if (singleFile && singleFile.length > 0) {
         console.log(`A filename '${singleFile}' in the folder '${rootExportPath}' has been requested so only processing that file `);
         ExportPDF (exeCmd, rootExportPath, singleFile, outputFile, extraParams, logInfo, logError);
     } else  {
         console.log(`Processing the contents of the folder '${rootExportPath}' `);
         ExportPDF (exeCmd, rootExportPath, "" , outputFile, extraParams, logInfo, logError);
     }
 }