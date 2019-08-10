import tl = require("vsts-task-lib/task");
import { basename } from "path";

import {
    logInfo,
    logError,
    getSystemAccessToken
}  from "./agentSpecific";

export async function run() {
    try {

        let scriptFolder = tl.getInput("scriptFolder");
        let resultsFile = tl.getInput("resultsFile");
        let run32Bit = tl.getInput("run32Bit");
        let additionalModulePath = tl.getInput("additionalModulePath");
        let Tag = tl.getInput("Tag");
        let ExcludeTag = tl.getInput("ExcludeTag");
        let CodeCoverageOutputFile = tl.getInput("CodeCoverageOutputFile");
        let CodeCoverageFolder = tl.getInput("CodeCoverageFolder");
        let ScriptBlock = tl.getInput("ScriptBlock");

        // we need to not pass the null param
        var args = [".\\pester.ps1",
                    "-scriptFolder", scriptFolder,
                    "-resultsFile", resultsFile,
                    "-run32Bit", run32Bit,
                ];

        if (additionalModulePath) {
            args.push("-additionalModulePath");
            args.push(additionalModulePath);
        }

        if (Tag) {
            args.push("-Tag");
            args.push(Tag);
        }

        if (ExcludeTag) {
            args.push("-ExcludeTag");
            args.push(ExcludeTag);
        }

        if (CodeCoverageOutputFile) {
            args.push("-CodeCoverageOutputFile");
            args.push(CodeCoverageOutputFile);
        }

        if (CodeCoverageFolder) {
            args.push("-CodeCoverageFolder");
            args.push(CodeCoverageFolder);
        }

        if (ScriptBlock) {
            args.push("-ScriptBlock");
            args.push(ScriptBlock);
        }

        var spawn = require("child_process").spawn, child;
        child = spawn("powershell.exe", args);
        child.stdout.on("data", function (data) {
            logInfo("Powershell Data: " + data);
        });
        child.stderr.on("data", function (data) {
            logError("Powershell Errors: " + data);
        });
        child.on("exit", function () {
            logInfo("Powershell Script finished");
        });
    }
    catch (err) {
        logError(err);
    }
}

run();