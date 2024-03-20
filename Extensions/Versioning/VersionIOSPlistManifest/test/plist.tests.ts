import "jest";

import {
    getSplitVersionParts,
    updateManifestFile,
    findFiles,
    extractVersion
} from "../src/ApplyVersionToManifestFunctions";

import * as fs from "fs";
import * as fse from "fs-extra";
const copyFileSync = require("fs-copy-file-sync");

describe ("Find files tests", () => {

    it ("should be able to find one file", () => {
        var filelist = findFiles ("test/testdata", "sample.xml.initial" , filelist);
        expect(filelist.length).toBe(1);
    });
});

describe ("Version number split tests", () => {

    it ("should be able to get version name with . delimiters", () => {
        var actual = getSplitVersionParts (false, "\d+.\d+.\d+.\d+", "{1}.{2}", "7.6.17334.5");
        expect(actual).toBe("7.6");
    });

    it ("should be able to get version code with . delimiters", () => {
        var actual = getSplitVersionParts(false, "\d+.\d+.\d+.\d+", "{3}{4}", "7.6.17334.5");
        expect(actual).toBe("173345");
    });

    it ("should be able to get version name with complex delimiters", () => {
        var actual = getSplitVersionParts (false, "\d+.\d+.\d+.\d+_\d+", "{1}-{2}-{3}-{4}-{5}", "2017.12.5.1_11760");
        expect(actual).toBe("2017-12-5-1-11760");
     });

     it ("should be able to inject a version", () => {
      var actual = getSplitVersionParts (true, "\d+.\d+.\d+.\d+", "{1}.{2}.{3}", "7.6");
      expect(actual).toBe("7.6");
  });

});

describe("Test the file processing", () => {
    beforeEach(function() {
      // make a copy we can overwrite with breaking test data
      copyFileSync("test/testdata/sample.xml.initial", "test/testdata/sample.xml");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/sample.xml";
      updateManifestFile(
        file,
        {
          "CFBundleVersion": 3.4,
          "CFBundleShortVersionString": 2.1
        });

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    afterEach(function() {
      // remove the file if created
      fse.removeSync("test/testdata/sample.xml");
    });

  });
