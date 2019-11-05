import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile,
  getSplitVersionParts
} from "../src/AppyVersionToJSONFileFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe ("Find files tests", () => {

  it ("should be able to find 6 files with recursion", () => {
      var filelist = findFiles ("test/testdata", "package.json.initial" , filelist, true);
      expect(filelist.length).to.equal(6);
  });

  it ("should be able to find 2 files with no recursion", () => {
    var filelist = findFiles ("test/testdata", "package.json.initial" , filelist, false);
    expect(filelist.length).to.equal(2);
  });

  it ("should be able to find 4 files with recursion and wildcard", () => {
    var filelist = findFiles ("test/testdata", "^package.json.initial" , filelist, true);
    expect(filelist.length).to.equal(4);
  });

  it ("should be able to find 1 file with no recursion and wildcard", () => {
    var filelist = findFiles ("test/testdata", "^package.json.initial" , filelist, false);
    expect(filelist.length).to.equal(1);
  });
});
