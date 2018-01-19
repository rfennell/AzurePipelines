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

describe("Test the update ARM file processing", () => {
    before(function() {
      // make a copy we can overright with breaking test data
      copyFileSync("test/testdata/ARMtemplate.json.initial", "test/testdata/ARMtemplate.json");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/ARMtemplate.json";
      ProcessFile(file, "contentVersion", "1.2.3.4");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/*.json");
    });
  }
);

describe("Test the add tag ARM file processing", () => {
  before(function() {
    // make a copy we can overright with breaking test data
    copyFileSync("test/testdata/ARMtemplate.json.noversion.initial", "test/testdata/ARMtemplate.json");
  });

  it("should be able to update a version in a file", () => {
    var file = "test/testdata/ARMtemplate.json";
    ProcessFile(file, "contentVersion", "1.2.3.4");

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`${file}.noversion.expected`);

    expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
  });

  after(function() {
    // remove the file if created
    del.sync("test/testdata/*.json");
  });
}
);
