import { findFiles } from "../src/FileUpdateFunctions";

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
  it("should find 5 matching files when using resursion and valid name", () => {
    let fileList ;
    fileList = findFiles("test/testdata", "*.xml", true, fileList) ;
    expect(Object.keys(fileList).length).to.equal(5);
  });

  it("should find 5 matching files when not using resursion and valid name", () => {
    let fileList ;
    fileList = findFiles("test/testdata", "*.xml", false, fileList) ;
    expect(Object.keys(fileList).length).to.equal(4);
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