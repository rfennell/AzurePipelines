import { expect } from "chai";
import { convertSarifToXml } from "../src/Sarif2JUnitConverterFunctions";
import * as fs from "fs";

var lastLogMessage = "";
var lastErrorMessage = "";

function logInfo(msg) {
    lastLogMessage = msg;
}

function logError(msg: string) {
    lastErrorMessage = msg;
}

describe("Sarif2JUnitConverter", () => {
    const xmlFilePath = "test/out.xml";

    afterEach(() => {
        // Clean up the generated XML file after each test
        if (fs.existsSync(xmlFilePath)) {
            fs.unlinkSync(xmlFilePath);
        }
    });

    it("should convert valid SARIF to XML", () => {
        // Arrange

        // Act
        convertSarifToXml("test/bicep.sarif", xmlFilePath, logError, logInfo);

        // Assert
        expect(fs.existsSync(xmlFilePath)).to.be.true;
        const actual = fs.readFileSync(xmlFilePath, "utf8").replace(/\r\n/g, "\n");
        const expected = fs.readFileSync("test/bicep.junit", "utf8").replace(/\r\n/g, "\n");

        expect(actual.length).to.equal(expected.length);
        expect(actual).to.equal(expected);

    });

    it("should not generate anything with missing SARIF file", () => {
        // Call the function with a non-existent SARIF file
        convertSarifToXml("test/nonexistent.sarif", xmlFilePath, logError, logInfo);

        // Assert that the XML file is not created
        expect(fs.existsSync(xmlFilePath)).to.be.false;
        expect(lastErrorMessage).to.equal("SARIF file not found: test/nonexistent.sarif");
    });

    it("should no generate anythingg for malformed SARIF file", () => {
        // Call the function with a non-existent SARIF file
        convertSarifToXml("test/bad-bicep.sarif", xmlFilePath, logError, logInfo);

        // Assert that the XML file is not created
        expect(fs.existsSync(xmlFilePath)).to.be.false;
        expect(lastErrorMessage).to.equal("Failed to parse SARIF file: test/bad-bicep.sarif");
    });
});