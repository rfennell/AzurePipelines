import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { SetWorkingFolder } from "../src/GitWikiFuntions";
import { logInfo } from "../src/agentSpecific";

describe("Test on the target folder creation", () => {
    it("should be able to use a path", () => {
        SetWorkingFolder(".\\", "/testdata/subfolder/file.md", logInfo);
    });

    it("should be use filename only", () => {
      SetWorkingFolder(".\\", "file.md", logInfo);
  });

  it("should be use filename only with a leading /", () => {
    SetWorkingFolder(".\\", "/file1.md", logInfo);
});

it("should be use filename only with a leading \\", () => {
  SetWorkingFolder(".\\", "\\file1.md", logInfo);
});

});
