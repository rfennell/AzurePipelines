import { findFiles,
         processFile,
         processFiles
} from "../src/FileUpdateFunctions";

import fs = require("fs") ;
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");
import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

function loggingFunction (msg: string) {
   // a way to dump the console message if needed, uncomment line below if needed
   // console.log(msg);
}

describe("ProcessFile function", () => {
    it("should update inner text on a node", () => {
      let rawContent = fs.readFileSync("test/testdata/1.xml").toString();
      let expected = fs.readFileSync("test/testdata/1a.updated").toString();
      let updateDoc = processFile(
        "/configuration/appSettings/add[@key='Enabled']",
        "In memory test file",
        rawContent,
        "true",
        "",
        loggingFunction);
        expect(updateDoc.toString()).to.equal(expected.toString());
    });

    it("should update inner text on a node with namespace", () => {
      let rawContent = fs.readFileSync("test/testdata/3.xml").toString();
      let expected = fs.readFileSync("test/testdata/3.updated").toString();
      let updateDoc = processFile(
        "/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='SqlCmdVariable'][@*[local-name()='Include' and .='Version']]/*[local-name()='Value']",
        "In memory test file",
        rawContent,
        "1.2.3.4",
        "",
        loggingFunction);
        expect(updateDoc.toString()).to.equal(expected.toString());
    });

    it("should update named attribute on a node", () => {
        let rawContent = fs.readFileSync("test/testdata/1.xml").toString();
        let expected = fs.readFileSync("test/testdata/1b.updated").toString();
        let updateDoc = processFile(
          "/configuration/appSettings/add[@key='Version']",
          "In memory test file",
          rawContent,
          "9.9.9.9",
          "value",
          loggingFunction);
          expect(updateDoc.toString()).to.equal(expected.toString());
    });

    it("should throw error when named attribute cannot be found", () => {
      let rawContent = fs.readFileSync("test/testdata/1.xml").toString();

      expect(function () { // have to wrapper in function
        let updateDoc = processFile(
          "/configuration/appSettings/add[@key='Version']",
          "In memory test file",
          rawContent,
          "9.9.9.9",
          "missingvalue",
          loggingFunction);
       }).to.throw(Error);
    });
});