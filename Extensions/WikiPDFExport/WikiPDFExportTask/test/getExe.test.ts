import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { GetExePath } from "../src/ExportFunctions";
const del = require("del");

describe("Get Exe Path ", () => {
  it("should be able download the release on windows", async () => {
    var actual = await GetExePath("", ".\\testdata", true);
    expect(actual).to.equal(`".\\testdata\\azuredevops-export-wiki.exe"`);
  }).timeout(20000);     // the default is 2000ms and that is too fast or the download

  it("should be able download the release on non-windows", async () => {
    var actual = await GetExePath("", ".\\testdata", false);
    expect(actual).to.equal(`"./testdata/azuredevops-export-wiki.exe"`);
  }).timeout(20000);     // the default is 2000ms and that is too fast or the download

  it("should be able to override the release download", async () => {
    var actual = await GetExePath(".\\testdata\\dummy.exe.txt", "", true);
    expect(actual).to.equal(`".\\testdata\\dummy.exe.txt"`);
  });

  it("should be able to override the release download", async () => {
    var actual = await GetExePath(".\\testdata\\dummy.exe.txt", "", true);
    expect(actual).to.equal(`".\\testdata\\dummy.exe.txt"`);
  });

  after(() => {
    // tidy up as the exe is too big
    del(".\\testdata\\azuredevops-export-wiki.exe");
  });

});
