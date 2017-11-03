"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const tl = require("vsts-task-lib/task");
// moving the logging function to a separate file
function logDebug(msg) {
    tl.debug(msg);
}
exports.logDebug = logDebug;
function logWarning(msg) {
    tl.warning(msg);
}
exports.logWarning = logWarning;
function logInfo(msg) {
    console.log(msg);
}
exports.logInfo = logInfo;
function logError(msg) {
    tl.error(msg);
}
exports.logError = logError;
function getVariable(name) {
    return tl.getInput(name);
}
exports.getVariable = getVariable;
function writeVariable(variableName, value) {
    if (variableName) {
        logInfo(`Writing output variable ${variableName}`);
        // the newlines cause a problem only first line shown
        // so remove them
        //var newlineRemoved = value.split("\n").join("  ");
        var newlineRemoved = value.replace(/\n/gi, '`n');
        tl.setVariable(variableName, newlineRemoved);
    }
}
exports.writeVariable = writeVariable;
// Below logic exists in nuget common module as well, but due to tooling issue
// where two tasks which use different tasks lib versions can't use the same common
// module, it's being duplicated here. 
function getSystemAccessToken() {
    tl.debug('Getting credentials for local feeds');
    var auth = tl.getEndpointAuthorization('SYSTEMVSSCONNECTION', false);
    if (auth.scheme === 'OAuth') {
        tl.debug('Got auth token');
        return auth.parameters['AccessToken'];
    }
    else {
        tl.warning(tl.loc('BuildCredentialsWarn'));
    }
}
exports.getSystemAccessToken = getSystemAccessToken;
//# sourceMappingURL=AgentSpecificFunctions.js.map