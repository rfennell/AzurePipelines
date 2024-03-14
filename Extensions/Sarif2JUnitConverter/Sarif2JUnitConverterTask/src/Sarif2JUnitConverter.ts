import * as fs from "fs";
import * as xmlbuilder from "xmlbuilder";
import tl = require("azure-pipelines-task-lib/task");

function logInfo(msg) {
    console.log(msg);
}

function logError (msg: string) {
    tl.error(msg);
    tl.setResult(tl.TaskResult.Failed, msg);
}

export async function convertSarifToXml(sarifFilePath: string, xmlFilePath: string) {

    if (!fs.existsSync(sarifFilePath)) {
       logError(`SARIF file not found: ${sarifFilePath}`);
    }

    logInfo(`Read the SARIF file from  ${sarifFilePath})`);
    const sarifData = fs.readFileSync(sarifFilePath, "utf8");

    // Parse the SARIF JSON
    const sarifJson = JSON.parse(sarifData);

    // Create an XML root
    const xmlRoot = xmlbuilder.create("root");

    // Convert the SARIF JSON to XML
    for (const run of sarifJson.runs) {
        const runElement = xmlRoot.ele("run");
        const toolElement = runElement.ele("tool");
        toolElement.ele("driver", { "name": run.tool.driver.name });

        for (const result of run.results) {
            const resultElement = runElement.ele("result", { "ruleId": result.ruleId, "level": result.level });
            resultElement.ele("message", { "text": result.message.text });

            for (const location of result.locations) {
                const locationElement = resultElement.ele("location");
                const physicalLocationElement = locationElement.ele("physicalLocation");
                physicalLocationElement.ele("artifactLocation", { "uri": location.physicalLocation.artifactLocation.uri });
                physicalLocationElement.ele("region", { "startLine": location.physicalLocation.region.startLine, "charOffset": location.physicalLocation.region.charOffset });
            }
        }
    }

    // Convert the XML to a string
    const xmlString = xmlRoot.end({ pretty: true });

    logInfo(`Write the XML string to a file ${xmlFilePath})`);
    fs.writeFileSync(xmlFilePath, xmlString);
}


var sarifFile = tl.getInput("sarifFile");
var junitFile = tl.getInput("junitFile");
logInfo(`Variable: sarifFile [${sarifFile}]`);
logInfo(`Variable: junitFile [${junitFile}]`);

convertSarifToXml(sarifFile, junitFile);
