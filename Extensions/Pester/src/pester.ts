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
        let resultsFile = tl.getVariable("resultsFile");
        let run32Bit = tl.getVariable("run32Bit");
        let additionalModulePath = tl.getVariable("additionalModulePath");
        let Tag = tl.getVariable("Tag");
        let ExcludeTag = tl.getVariable("ExcludeTag");
        let CodeCoverageOutputFile = tl.getVariable("addCodeCoverageOutputFile");
        let CodeCoverageFolder = tl.getVariable("CodeCoverageFolder");
        let ScriptBlock = tl.getVariable("ScriptBlock");

        var spawn = require("child_process").spawn, child;
        child = spawn(
            "powershell.exe",
            ["..\\task\\pester.ps1",
            "-scriptFolder", scriptFolder,
            "-resultsFile", resultsFile,
            "-run32Bit", run32Bit,
            "-additionalModulePath", additionalModulePath,
            "-Tag", Tag,
            "-ExcludeTag", ExcludeTag,
            "-CodeCoverageOutputFile", CodeCoverageOutputFile,
            "-CodeCoverageFolder", CodeCoverageFolder,
            "-ScriptBlock", ScriptBlock]);
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