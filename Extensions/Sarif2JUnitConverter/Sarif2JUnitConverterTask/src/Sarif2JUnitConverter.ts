import {convertSarifToXml, logError, logInfo} from "./Sarif2JUnitConverterFunctions";
import tl = require("azure-pipelines-task-lib/task");

var sarifFile = tl.getInput("sarifFile");
var junitFile = tl.getInput("junitFile");
logInfo(`Variable: sarifFile [${sarifFile}]`);
logInfo(`Variable: junitFile [${junitFile}]`);

convertSarifToXml(sarifFile, junitFile);
