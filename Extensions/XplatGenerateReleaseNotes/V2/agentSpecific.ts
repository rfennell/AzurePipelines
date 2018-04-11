import tl = require("vsts-task-lib/task");
require("vso-node-api");
import * as vstsInterfaces from "vso-node-api/interfaces/common/VsoBaseInterfaces";

var taskJson = require("./task.json");
const area: string = "XplatGenerateReleaseNotes";

export interface IAgentSpecificApi {
    logInfo(msg: string): void;
    logDebug(msg: string): void;
    logError(msg: string): void;
    publishEvent(feature, properties: any): void;
    writeVariable (variableName: string, value: string): void;
}

export class AgentSpecificApi implements IAgentSpecificApi {

    writeVariable(variableName: string, value: string): void {
        if (variableName) {
            this.logInfo(`Writing output variable ${variableName}`);
            // the newlines cause a problem only first line shown
            // so remove them
            var newlineRemoved = value.replace(/\n/gi, "`n");
            tl.setVariable(variableName, newlineRemoved );
        }
    }

    public logInfo(msg: string) {
        console.log(msg);
    }

    public logDebug(msg: string) {
        tl.debug(msg);
    }

    public logError(msg: string) {
        tl.error(msg);
    }

    public publishEvent(feature, properties: any): void {
        try {
            var splitVersion = (process.env.AGENT_VERSION || "").split(".");
            var major = parseInt(splitVersion[0] || "0");
            var minor = parseInt(splitVersion[1] || "0");
            let telemetry = "";
            if (major > 2 || (major === 2 && minor >= 120)) {
                telemetry = `##vso[telemetry.publish area=${area};feature=${feature}]${JSON.stringify(Object.assign(this.getDefaultProps(), properties))}`;
            }
            else {
                if (feature === "reliability") {
                    let reliabilityData = properties;
                    telemetry = "##vso[task.logissue type=error;code=" + reliabilityData.issueType + ";agentVersion=" + tl.getVariable("Agent.Version") + ";taskId=" + area + "-" + JSON.stringify(taskJson.version) + ";]" + reliabilityData.errorMessage;
                }
            }
            console.log(telemetry);
        }
        catch (err) {
            tl.warning("Failed to log telemetry, error: " + err);
        }
    }

    private getDefaultProps() {
        var hostType = (tl.getVariable("SYSTEM.HOSTTYPE") || "").toLowerCase();
        return {
            hostType: hostType,
            definitionName: hostType === "release" ? tl.getVariable("RELEASE.DEFINITIONNAME") : tl.getVariable("BUILD.DEFINITIONNAME"),
            processId: hostType === "release" ? tl.getVariable("RELEASE.RELEASEID") : tl.getVariable("BUILD.BUILDID"),
            processUrl: hostType === "release" ? tl.getVariable("RELEASE.RELEASEWEBURL") : (tl.getVariable("SYSTEM.TEAMFOUNDATIONSERVERURI") + tl.getVariable("SYSTEM.TEAMPROJECT") + "/_build?buildId=" + tl.getVariable("BUILD.BUILDID")),
            taskDisplayName: tl.getVariable("TASK.DISPLAYNAME"),
            jobid: tl.getVariable("SYSTEM.JOBID"),
            agentVersion: tl.getVariable("AGENT.VERSION"),
            version: taskJson.version
        };
    }

}
