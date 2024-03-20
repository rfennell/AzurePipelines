import "jest";
import { GetWorkingFolder, GetFolder } from "../src/GitWikiFuntions";
import { logInfo } from "../src/agentSpecific";
import { existsSync, fstat } from "fs";
import { pathToFileURL } from "url";
import * as fse from "fs-extra";

describe("Test on the target folder creation", () => {
    it("should be able to use a path", () => {
      var actual = GetWorkingFolder(".\\", "testdata\\subfolder\\1", logInfo);
      expect(existsSync(actual)).toBe(true);
      expect(actual).toBe("testdata\\subfolder\\1");
    });
    afterEach(function() {
      // remove the file if created
      fse.removeSync("testdata\\subfolder");
    });

    it("should be use filename only", () => {
      expect(GetWorkingFolder(".\\", "", logInfo)).toBe(".\\");
  });

});

describe("Check folder name extractions", () => {
  it("should only return subfolder for \\", () => {
    expect(GetFolder("C:\\test\\1\\2\\abc.md", "C:\\test")).toBe("1\\2");
  });

  it("should only return subfolder for /", () => {
    expect(GetFolder("C:/test/1/2/abc.md", "C:/test")).toBe("1\\2");
  });

  it("should only return subfolder for mixed \\ /", () => {
    expect(GetFolder("C:/test/1/2/abc.md", "C:\\test")).toBe("1\\2");
  });

});
