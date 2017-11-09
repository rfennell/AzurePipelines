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

describe("ProcessFiles function - no recursion", () => {
  before(function() {
     // make a copy we can overright with breaking test data
     copyFileSync("test/testdata/1.xml", "test/testdata/writeable.xml");
    });
  it("should find a list of files and update them when recursion is off", () => {
    let documentFilter = "test/testdata/writeable.xml";
    let expected = fs.readFileSync("test/testdata/1a.updated").toString();
    processFiles(
      documentFilter,
      false,
      "/configuration/appSettings/add[@key='Enabled']",
      "true",
      "",
      loggingFunction,
      loggingFunction);

    let updatedDoc = fs.readFileSync(documentFilter).toString();
    expect(updatedDoc.toString()).to.equal(expected.toString());

  });
  after(function() {
    // remove the file if created
    del.sync("test/testdata/writeable.xml");
  });
});

describe("ProcessFiles function - with recursion", () => {
  before(function() {
     // make a copy we can overright with breaking test data
     copyFileSync("test/testdata/1.xml", "test/testdata/writeable.xml");
     copyFileSync("test/testdata/folder1/3.xml", "test/testdata/folder1/writeable.xml");
    });
  it("should find a list of files and update them when recursion is on", () => {
    let expected = fs.readFileSync("test/testdata/1a.updated").toString();
    processFiles(
      "test/testdata/writeable.xml",
      true,
      "/configuration/appSettings/add[@key='Enabled']",
      "true",
      "",
      loggingFunction,
      loggingFunction);

    let updatedDoc = fs.readFileSync("test/testdata/writeable.xml").toString();
    expect(updatedDoc.toString()).to.equal(expected.toString());

    updatedDoc = fs.readFileSync("test/testdata/folder1/writeable.xml").toString();
    expect(updatedDoc.toString()).to.equal(expected.toString());

  });
  after(function() {
    // remove the file if created
    del.sync("test/testdata/writeable.xml");
    del.sync("test/testdata/folder1/writeable.xml");
  });
});