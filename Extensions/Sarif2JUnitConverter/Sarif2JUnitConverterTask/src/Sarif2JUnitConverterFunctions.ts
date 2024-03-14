import * as fs from "fs";
import * as xmlbuilder from "xmlbuilder";
import tl = require("azure-pipelines-task-lib/task");

export function logInfo(msg) {
    console.log(msg);
}

export function logError(msg: string) {
    tl.error(msg);
    tl.setResult(tl.TaskResult.Failed, msg);
}

export async function convertSarifToXml(sarifFilePath: string, xmlFilePath: string) {

    if (!fs.existsSync(sarifFilePath)) {
        logError(`SARIF file not found: ${sarifFilePath}`);
        return;
    }

    logInfo(`Read the SARIF file from  ${sarifFilePath})`);
    const sarifData = JSON.parse(fs.readFileSync(sarifFilePath, "utf8"));

    try {
        let xml = xmlbuilder.create("testsuites", { encoding: "utf-8" });

        var totalTests = 0;
        var totalFailures = 0;
        var totalErrors = 0;
        var totalSkipped = 0;

        // Transform the SARIF data into the JUnit format
        sarifData.runs.forEach((run) => {
            let testsuite = xml.ele("testsuite", { name: run.tool.driver.name });
            var tests = 0;
            var failures = 0;
            var errors = 0;
            var skipped = 0;

            run.results.forEach((result) => {
                let testcase = testsuite.ele("testcase", { name: result.ruleId });
                tests++;

                if (result.level === "error") {
                    failures++;
                    testcase.ele("failure", { message: `Ln ${result.locations[0].physicalLocation.region.startLine} ${result.message.text} ${result.locations[0].physicalLocation.artifactLocation.uri.replace("file:/", "")}` });
                }
            });

            testsuite.att("tests", tests);
            testsuite.att("failures", failures);
            testsuite.att("errors", errors);
            testsuite.att("skipped", skipped);

            totalTests += tests;
            totalFailures += failures;
            totalErrors += errors;
            totalSkipped += skipped;

        });

        xml.att("tests", totalTests);
        xml.att("failures", totalFailures);
        xml.att("errors", totalErrors);
        xml.att("skipped", totalSkipped);

        logInfo(`Write the XML string to a file ${xmlFilePath})`);
        fs.writeFileSync(xmlFilePath, xml.end({ pretty: true }), "utf8");
    } catch (err) {
        logError(`Failed to parse SARIF file: ${sarifFilePath}`);
    }
}