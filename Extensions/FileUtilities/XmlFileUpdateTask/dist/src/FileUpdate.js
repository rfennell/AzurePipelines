"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path = require("path");
const fs = require("fs");
const FileUpdateFunctions_1 = require("./FileUpdateFunctions");
const agentSpecificFunctions_1 = require("./agentSpecificFunctions");
const filename = agentSpecificFunctions_1.getVariable("filename");
const xpathQuery = agentSpecificFunctions_1.getVariable("xpath");
const attribute = agentSpecificFunctions_1.getVariable("attribute");
const value = agentSpecificFunctions_1.getVariable("value");
const recurse = new Boolean(agentSpecificFunctions_1.getVariable("recurse"));
agentSpecificFunctions_1.logInfo(`Param: filename - ${filename}`);
agentSpecificFunctions_1.logInfo(`Param: recurse - ${recurse}`);
agentSpecificFunctions_1.logInfo(`Param: xpath - ${xpathQuery}`);
agentSpecificFunctions_1.logInfo(`Param: attribute - ${attribute}`);
agentSpecificFunctions_1.logInfo(`Param: value - ${value}`);
let files;
FileUpdateFunctions_1.findFiles(path.dirname(filename), path.basename(filename), recurse, files);
files.forEach(file => {
    let rawContent = fs.readFileSync(file).toString();
    document = FileUpdateFunctions_1.processFile(xpathQuery, file, rawContent, value, attribute, agentSpecificFunctions_1.logInfo);
    fs.writeFileSync(file, document);
});
//# sourceMappingURL=FileUpdate.js.map