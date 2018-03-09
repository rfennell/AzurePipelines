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

describe("ProcessFiles function - with recursion", () => {
  before(function() {
     // make a copy we can overwrite with breaking test data
     copyFileSync("test/testdata/1.xml", "test/testdata/writeable.xml");
     copyFileSync("test/testdata/folder1/3.xml", "test/testdata/folder1/writeable.xml");
    });
  it("should find a list of files and update them when recursion is on", () => {
    let expected = fs.readFileSync("test/testdata/1a.updated").toString();
    processFiles(
      "test/testdata/writeable.xml",
      "True",
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
