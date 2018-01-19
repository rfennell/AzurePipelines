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

  it ("should be able to find one file", () => {
      var filelist = findFiles ("test/testdata", "package.json.initial" , filelist);
      expect(filelist.length).to.equal(1);
  });
});
