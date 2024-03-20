import "jest";

import { findFiles,
  ProcessFile,
  SplitArrayOfNames

} from "../src/AppyVersionToAssembliesFunctions";

describe("Test the find file processing", () => {

  it("should be able to find only .netcore project files", () => {
      var files = findFiles(`test/testdata`, ".csproj.initial", files, ["Microsoft.NET.Sdk"]);
      expect(files.length).toBe(9);
    });

    it("should be able to find only .netcore project files with different SDKs", () => {
      var input = "Microsoft.NET.Sdk,  MSBuild.Sdk.Extras ";
      var files = findFiles(`test/testdata`, ".csproj.initial", files, SplitArrayOfNames(input));
      expect(files.length).toBe(10);
    });

    it("should not find any  .csproj files is empty string of SDKs passed", () => {
      var input = "";
      var files = findFiles(`test/testdata`, ".csproj.initial", files, SplitArrayOfNames(input));
      expect(files.length).toBe(0);
    });

    it("should be able to find a directory.build.props file with no SDK passed", () => {
      var input = "";
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitArrayOfNames(input));
      expect(files.length).toBe(1);
    });

    it("should be able to find a directory.build.props file with no SDK is null", () => {
      var input = null;
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitArrayOfNames(input));
      expect(files.length).toBe(1);
    });

    it("should be able to find a directory.build.props file with SDK passed", () => {
      var input = "Microsoft.NET.Sdk";
      var files = findFiles(`test/testdata`, "directory.build.props.initial", files, SplitArrayOfNames(input));
      expect(files.length).toBe(1);
    });

});