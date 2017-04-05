import tl = require('vsts-task-lib/task');

// moving the logging function to a separate file

export function logDebug (msg :string)
{
    tl.debug(msg);
}

export function logWarning (msg :string)
{
    tl.warning(msg);
 }

export function logInfo (msg :string)
{
     console.log(msg);
}

export function logError (msg :string)
{
    tl.error(msg);
}

export function writeVariable (variableName : string ,value : string)
{
    tl.setVariable(variableName, value);
    logInfo(`Writing output variable ${variableName}`)
}

// Below logic exists in nuget common module as well, but due to tooling issue
// where two tasks which use different tasks lib versions can't use the same common
// module, it's being duplicated here. 
export function getSystemAccessToken(): string {
    tl.debug('Getting credentials for local feeds');
    var auth = tl.getEndpointAuthorization('SYSTEMVSSCONNECTION', false);
    if (auth.scheme === 'OAuth') {
        tl.debug('Got auth token');
        return auth.parameters['AccessToken'];
    } else {
        tl.warning(tl.loc('BuildCredentialsWarn'));
    }
}
