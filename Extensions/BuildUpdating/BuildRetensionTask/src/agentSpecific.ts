import tl = require("azure-pipelines-task-lib/task");
import fs = require("fs");

// moving the logging function to a separate file

export function logDebug (msg: string) {
    tl.debug(msg);
}

export function logWarning (msg: string) {
    tl.warning(msg);
 }

export function logInfo (msg: string) {
     console.log(msg);
}

export function logError (msg: string) {
    tl.error(msg);
    tl.setResult(tl.TaskResult.Failed, msg);
}

export function writeVariable (variableName: string, value: string) {
     if (variableName) {
        logInfo(`Writing output variable ${variableName}`);
        // the newlines cause a problem only first line shown
        // so remove them
        var newlineRemoved = value.replace(/\n/gi, "`n");
        tl.setVariable(variableName, newlineRemoved );
    }
}

export function getSystemAccessToken(): string {
    tl.debug("Getting credentials the agent is running as");
    var auth = tl.getEndpointAuthorization("SYSTEMVSSCONNECTION", false);
    if (auth.scheme === "OAuth") {
        tl.debug("Found an OAUTH token");
        return auth.parameters["AccessToken"];
    } else {
        tl.warning(tl.loc("BuildCredentialsWarn"));
    }
}