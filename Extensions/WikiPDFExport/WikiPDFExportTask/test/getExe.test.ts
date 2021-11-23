import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { GetExePath } from "../src/ExportFunctions";
const del = require("del");

describe("Get Exe Path ", () => {
  it("should be able download the pre release", async () => {
    var actual = await GetExePath("", "./testdata", true, "Windows_NT");
    expect(actual).to.equal(`testdata\\azuredevops-export-wiki.exe`);
  }).timeout(20000);     // the default is 2000ms and that is too fast or the download

  it("should be able download the latest production windows release", async () => {
    var actual = await GetExePath("", "./testdata", false, "Windows_NT");
    expect(actual).to.equal(`testdata\\azuredevops-export-wiki.exe`);
  }).timeout(20000);     // the default is 2000ms and that is too fast or the download

  it("should be able download the latest production Linux release", async () => {
    var actual = await GetExePath("", "./testdata", false, "Linux");
    expect(actual).to.equal(`testdata\\azuredevops-export-wiki`);
  }).timeout(20000);     // the default is 2000ms and that is too fast or the download

  it("should be able to override the release download", async () => {
    var actual = await GetExePath(".\\testdata\\dummy.exe.txt", "", true, "Windows_NT");
    expect(actual).to.equal(`.\\testdata\\dummy.exe.txt`);
  });

  it("should be able to override the release download", async () => {
    var actual = await GetExePath(".\\testdata\\dummy.exe.txt", "", true, "Windows_NT");
    expect(actual).to.equal(`.\\testdata\\dummy.exe.txt`);
  });

  after(() => {
    // tidy up as the exe is too big
    del(".\\testdata\\azuredevops-export-wiki.exe");
    del(".\\testdata\\azuredevops-export-wiki");
  });

});
