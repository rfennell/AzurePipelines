import { processFiles } from "../src/FileUpdateFunctions";

import fs = require("fs") ;
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

const chai    = require("chai");
const expect  = require("chai").expect;
const chaiXml = require("chai-xml");
// loads the plugin
chai.use(chaiXml);

// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import exp = require("constants");

function loggingFunction (msg: string) {
   // a way to dump the console message if needed, uncomment line below if needed
   // console.log(msg);
}

describe("ProcessFiles function - no recursion", () => {
  before(function() {
     // make a copy we can overright with breaking test data
     copyFileSync("test/testdata/1.xml", "test/testdata/writeable.xml");
     copyFileSync("test/testdata/folder1/3.xml", "test/testdata/folder1/writeable.xml");
    });
  it("should find a list of files and update them when recursion is off", () => {
    let documentFilter = "test/testdata/writeable.xml";
    processFiles(
      documentFilter,
      "False",
      "/configuration/appSettings/add[@key='Enabled']",
      "true",
      "",
      loggingFunction,
      loggingFunction);

    // updates the root
    let updatedDoc = fs.readFileSync(documentFilter).toString();
    let expected = fs.readFileSync("test/testdata/1a.updated").toString();
    expect(updatedDoc.length).to.equal(expected.length);
    expect(updatedDoc).xml.to.be.valid();
    expect(updatedDoc).xml.to.equal(expected);

    // but not the sub folder
    updatedDoc = fs.readFileSync("test/testdata/folder1/writeable.xml").toString();
    let sourceDoc = fs.readFileSync("test/testdata/folder1/3.xml").toString();
    expect(updatedDoc.length).to.equal(sourceDoc.length);
    expect(updatedDoc).xml.to.equal(sourceDoc);

  });
  after(function() {
    // remove the file if created
    del.sync("test/testdata/writeable.xml");
    del.sync("test/testdata/folder1/writeable.xml");
  });
});