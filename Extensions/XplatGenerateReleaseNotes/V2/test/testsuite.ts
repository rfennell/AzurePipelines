import { expect, assert } from "chai";
import path = require("path");
import ttm = require("vsts-task-lib/mock-test");
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

const debug = process.env["NODE_ENV"] === "debugtest";
if (debug) {
    console.log("------ RUNNING IN DEBUG ------------");
}

// let taskPath = path.join(__dirname, "..", "dist", "src", "GenerateReleaseNotes.js");
// let tr: tmrm.TaskMockRunner = new tmrm.TaskMockRunner(taskPath);

describe("a test suite", () => {
  it("should fail with no access token", () => {

    let tp = path.join(__dirname, "test-noaccesstoken.js");
    let tr: ttm.MockTestRunner = new ttm.MockTestRunner(tp);

    tr.run();
    if (debug) {
        console.log(tr.stdout);
    }
    // if (tr.stderr) {
    //     assert.fail(tr.stderr);
    //     return;
    // }

    expect(tr.failed, "should have failed");
  });
});