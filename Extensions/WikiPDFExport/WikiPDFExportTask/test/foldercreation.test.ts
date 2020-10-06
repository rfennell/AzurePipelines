import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { GetWorkingFolder, GetWorkingFile } from "../src/GitWikiFunctions";
import { logInfo } from "../src/agentSpecific";
import { existsSync, fstat } from "fs";
import { pathToFileURL } from "url";
const del = require("del");

describe("Test on the target folder creation", () => {
    it("should be able to use a path", () => {
      var actual = GetWorkingFolder(".\\", "testdata\\subfolder\\1\\file.md", logInfo);
      expect(existsSync(actual)).to.equal(true);
      expect(actual).to.equal("testdata\\subfolder\\1");
    });
    after(function() {
      // remove the file if created
      del.sync("testdata\\subfolder");
    });

    it("should be use filename only", () => {
      expect(GetWorkingFolder(".\\", "file.md", logInfo)).to.equal(".\\");
  });

  it("should be use filename only with a leading /", () => {
    expect(GetWorkingFolder(".\\", "/file1.md", logInfo)).to.equal(".\\");
  });

  it("should be use filename only with a leading \\", () => {
    expect(GetWorkingFolder(".\\", "\\file1.md", logInfo)).to.equal(".\\");
  });
});

describe("Test on the target file", () => {
  it("should be able to use a path", () => {
    expect(GetWorkingFile("testdata\\subfolder\\1\\file.md", logInfo)).to.equal("file.md");
  });

  it("should be use filename only", () => {
    expect(GetWorkingFile( "file.md", logInfo)).to.equal("file.md");
  });
});