import { expect } from "chai";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";
import { GetTrimmedUrl, GetProtocol } from "../src/GitWikiFunctions";
import { logInfo } from "../src/agentSpecific";
import { existsSync, fstat } from "fs";
import { pathToFileURL } from "url";
const del = require("del");

describe("Test stripping leading characters from url", () => {
  it("should be able to handle correct url", () => {
    var actual = GetTrimmedUrl("servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("servername/collection/project/_git/wikiname");
  });

  it("should be able to fix a lower case http", () => {
    var actual = GetTrimmedUrl("http://servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("servername/collection/project/_git/wikiname");
  });

  it("should be able to fix a upper case http", () => {
    var actual = GetTrimmedUrl("HTTP://servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("servername/collection/project/_git/wikiname");
  });

  it("should be able to fix with an @", () => {
    var actual = GetTrimmedUrl("http://richardfennell@servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("servername/collection/project/_git/wikiname");
  });

});

describe("Test getting protocol", () => {
  it("should be able to add a protocol", () => {
    var actual = GetProtocol("servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("https");
  });

  it("should be able to get a lower case http", () => {
    var actual = GetProtocol("http://servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("http");
  });

  it("should be able to get a upper case http", () => {
    var actual = GetProtocol("HTTP://servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("HTTP");
  });

  it("should be able to get protocol when there is an @", () => {
    var actual = GetProtocol("http://richardfennell@servername/collection/project/_git/wikiname", logInfo);
    expect(actual).to.equal("http");
  });

});
