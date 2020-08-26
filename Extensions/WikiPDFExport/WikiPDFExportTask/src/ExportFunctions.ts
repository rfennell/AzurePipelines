import * as process from "process";
import { logWarning } from "./agentSpecific";
import { exec } from "child_process";
import * as fs from "fs";

export async function ExportPDF(
    command,
    wikiRootPath,
    singleFile,
    outputFile,
    extraParams,
    logInfo,
    logError) {

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