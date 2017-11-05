import path = require("path") ;
import fs = require("fs") ;

import { findFiles,
         processFile
       } from "./FileUpdateFunctions";

import { logDebug,
         logWarning,
         logInfo,
         logError,
         getVariable
       }  from "./agentSpecificFunctions";

const filename = getVariable("filename");
const xpathQuery = getVariable("xpath");
const attribute = getVariable("attribute");
const value = getVariable("value");
const recurse = new Boolean(getVariable("recurse"));

logInfo (`Param: filename - ${filename}`);
logInfo (`Param: recurse - ${recurse}`);
logInfo (`Param: xpath - ${xpathQuery}`);
logInfo (`Param: attribute - ${attribute}`);
logInfo (`Param: value - ${value}`);

let files;
logDebug (`Looking in folder [${path.dirname(filename)}] for files that match pattern [${path.basename(filename)}]`);

files = findFiles(path.dirname(filename), path.basename(filename), recurse, files);

files.forEach(file => {
    let rawContent = fs.readFileSync(file).toString();
    document = processFile(xpathQuery, file, rawContent, value, attribute, logInfo);
    fs.writeFileSync(file, document);
});