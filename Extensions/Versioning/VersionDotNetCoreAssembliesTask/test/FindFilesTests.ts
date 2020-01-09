import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

import { findFiles,
  ProcessFile,
  SplitSDKName
} from "../src/AppyVersionToAssembliesFunctions";

import fs = require("fs");
const copyFileSync = require("fs-copy-file-sync");
const del = require("del");

describe("Test the find file processing", () => {

  it("should be able to find only .netcore project files", () => {
      var files = findFiles(`test/testdata`, ".csproj.initial", files, ["Microsoft.NET.Sdk"]);
      expect(files.length).equals(9);
    });

    it("should be able to find only .netcore project files with different SDKs", () => {
      var input = "Microsoft.NET.Sdk,  MSBuild.Sdk.Extras ";
      var files = findFiles(`test/testdata`, ".csproj.initial", files, SplitSDKName(input));
      expect(files.length).equals(10);
    });

    it("should not find any  .csproj files is empty string of SDKs passed", () => {
      var input = "";
      var files = findFiles(`test/testdata`, ".csproj.initial", files, SplitSDKName(input));
      expect(files.length).equals(0);
    });

    it("should be able to find a directory.build.props file with no SDK passed", () => {
      var input = "";
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitSDKName(input));
      expect(files.length).equals(1);
    });

    it("should be able to find a directory.build.props file with no SDK is null", () => {
      var input = null;
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitSDKName(input));
      expect(files.length).equals(1);
    });

    it("should be able to find a directory.build.props file with SDK passed", () => {
      var input = "Microsoft.NET.Sdk";
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitSDKName(input));
      expect(files.length).equals(1);
    });

});