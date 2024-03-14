import { expect } from "chai";
import { convertSarifToXml } from "../src/Sarif2JUnitConverterFunctions";
import * as fs from "fs";
import tl = require("azure-pipelines-task-lib/task");

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
        convertSarifToXml("test/bicep.sarif", xmlFilePath);

        // Assert
        expect(fs.existsSync(xmlFilePath)).to.be.true;
        const actual = fs.readFileSync(xmlFilePath, "utf8").replace(/\r\n/g, "\n");
        const expected = fs.readFileSync("test/bicep.junit", "utf8").replace(/\r\n/g, "\n");

        expect(actual.length).to.equal(expected.length);
        expect(actual).to.equal(expected);

    });

    it("should not generate anything with missing SARIF file", () => {
        // Call the function with a non-existent SARIF file
        convertSarifToXml("test/nonexistent.sarif", xmlFilePath);

        // Assert that the XML file is not created
        expect(fs.existsSync(xmlFilePath)).to.be.false;
    });

    it("should no generate anythingg for malformed SARIF file", () => {
        // Call the function with a non-existent SARIF file
        convertSarifToXml("test/bad-bicep.sarif", xmlFilePath);

        // Assert that the XML file is not created
        expect(fs.existsSync(xmlFilePath)).to.be.false;
    });
});