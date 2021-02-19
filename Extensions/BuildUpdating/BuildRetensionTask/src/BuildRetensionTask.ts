import tl = require("vsts-task-lib/task");
import { basename } from "path";

import {
    logInfo,
    logError,
    getSystemAccessToken
}  from "./agentSpecific";

export async function run() {
    try {

        // Get the build and release details
        let mode = tl.getInput("mode");
        let usedefaultcreds = tl.getInput("usedefaultcreds");
        let artifacts = tl.getInput("artifacts");
        let keepForever = tl.getInput("keepForever");

        let collectionUrl = process.env.SYSTEM_TEAMFOUNDATIONCOLLECTIONURI;
        let teamproject = process.env.SYSTEM_TEAMPROJECT;
        let releaseid = process.env.RELEASE_RELEASEID;
        let buildid = process.env.BUILD_BUILDID;

        // we need to get the verbose flag passed in as script flag
        var verbose = (tl.getVariable("System.Debug") === "true");

        let url = tl.getEndpointUrl("SYSTEMVSSCONNECTION", false);
        let token = tl.getEndpointAuthorizationParameter("SYSTEMVSSCONNECTION", "ACCESSTOKEN", false);

        // find the executeable
        let executable = "pwsh";
        if (tl.getVariable("AGENT.OS") === "Windows_NT") {
            if (!tl.getBoolInput("usePSCore")) {
                executable = "powershell.exe";
            }
            logInfo(`Using executable '${executable}'`);
        } else {
            logInfo(`Using executable '${executable}' as only only option on '${tl.getVariable("AGENT.OS")}'`);
        }

        // we need to not pass the null param
        var args = [__dirname + "\\BuildRetensionTask.ps1",
        "-collectionUrl", collectionUrl,
        "-token", token
        ];
        args.push("-teamproject");
        if (/\s/.test(teamproject)) {
            // It has any kind of whitespace
            args.push(`'${teamproject}'`);
        } else {
            args.push(teamproject);
        }

        if (releaseid) {
            args.push("-releaseid");
            args.push(releaseid);
        }

        if (keepForever) {
            args.push("-keepForever");
            args.push(keepForever);
        }

        if (buildid) {
            args.push("-buildid");
            args.push(buildid);
        }

        if (mode) {
            args.push("-mode");
            args.push(mode);
        }

        if (usedefaultcreds) {
            args.push("-usedefaultcreds");
            args.push(usedefaultcreds);
        }

        if (artifacts) {
            args.push("-artifacts");
            args.push(`'${artifacts}'`);
        }

        if (verbose) {
            args.push("-Verbose");
        }

        logInfo(`${executable} ${args.join(" ")}`);

        var spawn = require("child_process").spawn, child;
        child = spawn(executable, args);
        child.stdout.on("data", function (data) {
            logInfo(data.toString());
        });
        child.stderr.on("data", function (data) {
            logError(data.toString());
        });
        child.on("exit", function () {
            logInfo("Script finished");
        });
    }
    catch (err) {
        logError(err);
    }
}

run();