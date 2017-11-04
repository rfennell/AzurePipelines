import { findFiles,
         processFile
} from "../src/FileUpdateFunctions";

import fs = require("fs") ;
import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

function loggingFunction (msg: string) {
   // a way to dump the console message if needed, uncomment line below
   // console.log(msg);
}

describe("FindFiles function", () => {
  it("should find 3 matching files when using resursion and valid name", () => {
    let fileList ;
    fileList = findFiles("test/testdata", "*.xml", true, fileList) ;
    expect(Object.keys(fileList).length).to.equal(3);
  });

  it("should find 2 matching files when not using resursion and valid name", () => {
    let fileList ;
    fileList = findFiles("test/testdata", "*.xml", false, fileList) ;
    expect(Object.keys(fileList).length).to.equal(2);
  });

  it("should find no match with valid path and valid name", () => {
    let fileList ;
    fileList = findFiles("test/testdata", "*.XXX", true, fileList) ;
    expect(Object.keys(fileList).length).to.equal(0);
  });

  it("should throw exception with invalid path", () => {
    let fileList ;
    expect( function () { // have to wrapper in function
        findFiles("test/xxxx", "*.xml", true, fileList);
    }).to.throw(Error);
  });

});

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