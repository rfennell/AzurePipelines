import tl = require("vsts-task-lib/task");
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

// Below logic exists in nuget common module as well, but due to tooling issue
// where two tasks which use different tasks lib versions can't use the same common
// module, it's being duplicated here.
export function getSystemAccessToken(): string {
    tl.debug("Getting credentials for local feeds");
    var auth = tl.getEndpointAuthorization("SYSTEMVSSCONNECTION", false);
    if (auth.scheme === "OAuth") {
        tl.debug("Got auth token");
        return auth.parameters["AccessToken"];
    } else {
        tl.warning(tl.loc("BuildCredentialsWarn"));
    }
}
