import * as process from "process";
import { logWarning } from "./agentSpecific";
import { exec } from "child_process";
import * as fs from "fs";

// Define a function to filter releases.
function filterRelease(release) {
    // Filter out prereleases.
    return release.prerelease === false;
}

// Define a function to filter assets.
function filterAsset(asset) {
    // Select assets that contain the string 'windows'.
    return asset.name.indexOf("azuredevops-export-wiki.exe") >= 0;
}

async function DownloadExportExe(
    folder,
    logInfo,
    logError) {

    var downloadRelease = require("download-github-release");
    logInfo("Starting download of command line tool");
    await downloadRelease("MaxMelcher", "AzureDevOps.WikiPDFExport", folder, filterRelease, filterAsset, false)
    .then(function() {
        logInfo("Download done");
    })
    .catch(function(err) {
        logError(err.message);
    });
}

export async function ExportPDF(
    wikiRootPath,
    singleFile,
    outputFile,
    extraParams,
    logInfo,
    logError) {

        await DownloadExportExe(__dirname, logInfo, logError);
        var command = `${__dirname}\\azuredevops-export-wiki.exe`;
        if (!fs.existsSync(command)) {
            logError(`Cannot find command line tool ${command}`);
            return;
        }

        if (wikiRootPath.length > 0) {
            if (!fs.existsSync(`${wikiRootPath}`)) {
                logError(`Cannot find wiki folder ${wikiRootPath}`);
                return;
            } else {
                command += ` -p ${wikiRootPath}`;
            }
        }
        if (singleFile.length > 0) {
            if (!fs.existsSync(`${singleFile}`)) {
                logError(`Cannot find the requested file ${singleFile} to export`);
                return;
            } else {
                command += ` -s ${singleFile}`;
            }
        } else {
            if (!fs.existsSync(`${wikiRootPath}/.order`)) {
                logInfo(`No filename specified and cannot find the .order file in the root of the wiki, the exported PDF will therefore be empty`);
            }
        }
        if (outputFile.length > 0) {
            command += ` -o ${outputFile}`;
        } else {
            logError("No output file name provided");
            return;
        }

        if (extraParams.length > 0) {
            logInfo("Adding extra parameters to the command line");
            command += ` ${extraParams}`;
        }

        if (!command.includes("-v")) {
            logInfo("Adding the verbose flag to increase logging");
            command += ` -v`;
        }

    logInfo(`Using command ${command}`);
    exec(command, function (error, stdout, stderr) {
        logInfo(stdout);
        logInfo(stderr);
        if (error !== null) {
            logError(error);
        }
    });

}