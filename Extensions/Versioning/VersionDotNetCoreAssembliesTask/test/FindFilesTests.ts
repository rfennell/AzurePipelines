import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile
} from "../src/AppyVersionToAssembliesFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe("Test the find file processing", () => {

  it("should be able to find only .netcore project files", () => {
      var files = findFiles(`test/testdata`, ".csproj.initial", files);
      expect(files.length).equals(4);
    });

  });