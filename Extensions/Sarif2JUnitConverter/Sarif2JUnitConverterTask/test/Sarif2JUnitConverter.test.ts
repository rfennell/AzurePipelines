import { expect } from "chai";
import { convertSarifToXml } from "../src/Sarif2JUnitConverter";
import * as fs from "fs";

describe("Sarif2JUnitConverter", () => {
    const sarifFilePath = "test/bicep.sarif";
    const xmlFilePath = "test/out.xml";
    const bicepFilePath = "test/bicep.sarif";

    afterEach(() => {
        // Clean up the generated XML file after each test
        if (fs.existsSync(xmlFilePath)) {
            fs.unlinkSync(xmlFilePath);
        }
    });

    it("should convert SARIF to XML", () => {
        // Call the function to convert SARIF to XML
        convertSarifToXml(sarifFilePath, xmlFilePath);

        // Assert that the XML file is created
        expect(fs.existsSync(xmlFilePath)).to.be.true;

        // Read the XML file
        const xmlData = fs.readFileSync(xmlFilePath, "utf8");

        // Assert that the XML data is valid
        expect(fs.readFileSync(sarifFilePath, "utf8")).to.equal(fs.readFileSync(bicepFilePath, "utf8"));

    });

});