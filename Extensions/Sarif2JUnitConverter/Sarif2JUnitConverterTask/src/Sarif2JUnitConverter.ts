import {convertSarifToXml} from "./Sarif2JUnitConverterFunctions";
import tl = require("azure-pipelines-task-lib/task");

function logInfo(msg) {
    console.log(msg);
}

function logError(msg: string) {
    tl.error(msg);
    tl.setResult(tl.TaskResult.Failed, msg);
}

var sarifFile = tl.getInput("sarifFile");
var junitFile = tl.getInput("junitFile");
logInfo(`Variable: sarifFile [${sarifFile}]`);
logInfo(`Variable: junitFile [${junitFile}]`);

convertSarifToXml(sarifFile, junitFile, logError, logInfo);
