import { processFiles
       } from "./FileUpdateFunctions";

import { logDebug,
         logWarning,
         logInfo,
         logError,
         getVariable
       }  from "./AgentSpecificFunctions";

const filename = getVariable("filename");
const xpathQuery = getVariable("xpath");
const attribute = getVariable("attribute");
const value = getVariable("value");
const recurse = getVariable("recurse");

logInfo (`Param: filename - ${filename}`);
logInfo (`Param: recurse - ${recurse}`);
logInfo (`Param: xpath - ${xpathQuery}`);
logInfo (`Param: attribute - ${attribute}`);
logInfo (`Param: value - ${value}`);

processFiles (filename, recurse.valueOf(), xpathQuery, value, attribute, logInfo, logDebug );