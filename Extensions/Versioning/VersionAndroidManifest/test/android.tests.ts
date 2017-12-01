import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import {
    getVersionName,
    getVersionCode,
    updateManifestFile,
    findFiles
} from "../src/ApplyVersionToManifestFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe ("Find files tests", () => {

    it ("should be able to find one file", () => {
        var filelist = findFiles ("test/testdata", "sample.xml.initial" , filelist);
        expect(filelist.length).to.equal(1);
    });
});

describe ("Version number split tests", () => {

    it ("should be able to get version name", () => {
        var actual = getVersionName ("{1}.{2}", "7.6.17334.5");
        expect(actual).to.equal("7.6");
    });

    it ("should be able to get version code", () => {
        var actual = getVersionCode("{3}{4}", "7.6.17334.5");
        expect(actual).to.equal("173345");
    });

});

describe("Test the file processing", () => {
    before(function() {
      // make a copy we can overright with breaking test data
      copyFileSync("test/testdata/sample.xml.initial", "test/testdata/sample.xml");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/sample.xml";
      updateManifestFile(file, "34", "1.2");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/sample.xml");
    });

  });
