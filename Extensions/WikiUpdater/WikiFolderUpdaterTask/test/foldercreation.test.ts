import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { GetWorkingFolder, GetFolder } from "../src/GitWikiFuntions";
import { logInfo } from "../src/agentSpecific";
import { existsSync, fstat } from "fs";
import { pathToFileURL } from "url";
const del = require("del");

describe("Test on the target folder creation", () => {
    it("should be able to use a path", () => {
      var actual = GetWorkingFolder(".\\", "testdata\\subfolder\\1", logInfo);
      expect(existsSync(actual)).to.equal(true);
      expect(actual).to.equal("testdata\\subfolder\\1");
    });
    after(function() {
      // remove the file if created
      del.sync("testdata\\subfolder");
    });

    it("should be use filename only", () => {
      expect(GetWorkingFolder(".\\", "", logInfo)).to.equal(".\\");
  });

});

describe("Check folder name extractions", () => {
  it("should only return subfolder for \\", () => {
    expect(GetFolder("C:\\test\\1\\2\\abc.md", "C:\\test")).to.equal("1\\2");
  });

  it("should only return subfolder for /", () => {
    expect(GetFolder("C:/test/1/2/abc.md", "C:/test")).to.equal("1\\2");
  });

  it("should only return subfolder for mixed \\ /", () => {
    expect(GetFolder("C:/test/1/2/abc.md", "C:\\test")).to.equal("1\\2");
  });

});
