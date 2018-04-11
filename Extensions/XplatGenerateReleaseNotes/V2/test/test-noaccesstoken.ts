import ma = require("vsts-task-lib/mock-answer");
import tmrm = require("vsts-task-lib/mock-run");
import path = require("path");

let taskPath = path.join(__dirname, "..", "dist", "src", "GenerateReleaseNotes.js");
let tmr: tmrm.TaskMockRunner = new tmrm.TaskMockRunner(taskPath);
tmr.run();