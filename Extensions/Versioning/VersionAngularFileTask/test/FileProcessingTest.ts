import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile,
  getSplitVersionParts,
  extractVersion
} from "../src/AppyVersionToAngularFileFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe ("Version number split tests", () => {

  it ("should be able to get version name with . delimiters", () => {
      var actual = getSplitVersionParts (false, "\d+.\d+.\d+.\d+", "{1}.{2}.{3}", "7.6.17334.5");
      expect(actual).to.equal("7.6.17334");
  });

  it ("should be able to get version name with complex delimiters", () => {
      var actual = getSplitVersionParts (false, "\d+.\d+.\d+.\d+_\d+", "{1}-{2}-{3}", "2017.12.5.1_11760");
      expect(actual).to.equal("2017-12-5");
   });

   it ("should be able to injetc version and regex is ignored", () => {
    var actual = getSplitVersionParts (true, "\d+.\d+.\d+.\d+", "{1}.{2}.{3}.{4}", "2.0.577-dev");
    expect(actual).to.equal("2.0.577-dev");
 });

});

describe("Test the update file processing", () => {
    before(function() {
      // make a copy we can overright with breaking test data
      copyFileSync("test/testdata/environment.ts.initial", "test/testdata/environment.ts");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/environment.ts";
      ProcessFile(file, "version", "1.2.3.4");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/environment.ts");
    });
  }
);

describe("Test the add tag file processing", () => {
  before(function() {
    // make a copy we can overright with breaking test data
    copyFileSync("test/testdata/environment.ts.noversion.initial", "test/testdata/environment.ts");
  });

  it("should be able to update a version in a file", () => {
    var file = "test/testdata/environment.ts";
    ProcessFile(file, "version", "1.2.3.4");

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`${file}.expected`);

    expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
  });

  after(function() {
    // remove the file if created
    del.sync("test/testdata/environment.ts");
  });
}
);

describe("Test the version extraction", () => {

  it("should be able to extract just a version for a build number", () => {
    var actual = extractVersion(false, "\\d+\\.\\d+\\.\\d+", "ABC-1.2.3.4-XYZ");
    expect(actual).equals("1.2.3");
  });

  it("should be able to skip extracting a version for a build number", () => {
    var actual = extractVersion(true, "\\d+\\.\\d+\\.\\d+", "ABC-1.2.3.4-XYZ");
    expect(actual).equals("ABC-1.2.3.4-XYZ");
  });

});

describe("Test for Issue 615 double quotes", () => {
  before(function() {
    // make a copy we can overright with breaking test data
    copyFileSync("test/testdata/issue615-environment.ts.initial", "test/testdata/environment.ts");
  });

  it("should be able to update a version in a file", () => {
    var file = "test/testdata/environment.ts";
    ProcessFile(file, "version", "1.2.3.4");

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/issue615-environment.ts.expected`);

    expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
  });

  after(function() {
    // remove the file if created
    del.sync("test/testdata/environment.ts");
  });
}
);