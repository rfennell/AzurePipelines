import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile,
  getSplitVersionParts
} from "../src/AppyVersionToJSONFileFunctions";

import * as fs from "fs";
import * as fse from "fs-extra";
import * as copyFileSync from "fs-copy-file-sync";

describe("Test the update package file processing", () => {
    before(function() {
      // make a copy we can overright with breaking test data
      copyFileSync("test/testdata/package.json.initial", "test/testdata/package.json");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/package.json";
      ProcessFile(file, "version", "1.2.3");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      fse.removeSync("test/testdata/*.json");
    });
  }
);

describe("Test the add tag package file processing", () => {
  before(function() {
    // make a copy we can overright with breaking test data
    copyFileSync("test/testdata/package.json.noversion.initial", "test/testdata/package.json");
  });

  it("should be able to update a version in a file", () => {
    var file = "test/testdata/package.json";
    ProcessFile(file, "version", "1.2.3");

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`${file}.noversion.expected`);

    expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
  });

  after(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.json");
  });
}
);
