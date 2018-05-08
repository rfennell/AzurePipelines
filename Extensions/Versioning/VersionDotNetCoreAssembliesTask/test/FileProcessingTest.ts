import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile
} from "../src/AppyVersionToAssembliesFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe("Test the basic file processing", () => {
    before(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/core.csproj.initial", "test/testdata/core.csproj");
      copyFileSync("test/testdata/coreUTF8.csproj.initial", "test/testdata/coreUTF8.csproj");
    });

    it("should be able to update a AssemblyVersion in a file", () => {
      var file = "test/testdata/core.csproj";
      ProcessFile(file, "AssemblyVersion", "9.9.9.9");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    it("should be able to update a AssemblyVersion in a UTF8 file", () => {
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

  describe("Test the add field file processing", () => {
    before(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremissing.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to add a AssemblyVersion in a file", () => {
      var file = "test/testdata/core.csproj";
      ProcessFile(file, "AssemblyVersion", "9.9.9.9");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremissing.csproj.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/*.csproj");
    });

  });

  describe("Test the generic field file processing", () => {
    before(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremultiple.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to update a generic version field in a file", () => {
      var file = "test/testdata/core.csproj";
      ProcessFile(file, "", "9.9.9.9");

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremultiple.csproj.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/*.csproj");
    });

  });

  describe("Test the empty field file processing", () => {
    before(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremissing.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to add a detail version field in a file", () => {
      var file = "test/testdata/core.csproj";
      ProcessFile(file, "", "9.9.9.9", true);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremissingaddversion.csproj.expected`);

      expect(editedfilecontent.toString()).equals(expectedfilecontent.toString());
    });

    after(function() {
      // remove the file if created
      del.sync("test/testdata/*.csproj");
    });

  });