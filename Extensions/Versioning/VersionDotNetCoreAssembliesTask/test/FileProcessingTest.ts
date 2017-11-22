import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile
} from "../src/AppyVersionToAssembliesFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe("Test the file processing", () => {
    before(function() {
      // make a copy we can overright with breaking test data
      copyFileSync("test/testdata/core.csproj.initial", "test/testdata/core.csproj");
      copyFileSync("test/testdata/coreUTF8.csproj.initial", "test/testdata/coreUTF8.csproj");
    });

    it("should be able to update a version in a file", () => {
      var file = "test/testdata/core.csproj";
      ProcessFile(file, "AssemblyVersion", "9.9.9.9");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    it("should be able to update a version in a UTF8 file", () => {
      var file = "test/testdata/coreUTF8.csproj";
      ProcessFile(file, "AssemblyVersion", "9.9.9.9");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/*.csproj");
    });

  });
