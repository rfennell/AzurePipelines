import { WebApi } from "vso-node-api/WebApi";
import { ResourceRef } from "vso-node-api/interfaces/common/VSSInterfaces";
import { GitQueryCommitsCriteria, GitVersionType } from "vso-node-api/interfaces/GitInterfaces";
import { Change } from "vso-node-api/interfaces/BuildInterfaces";
import { ArtifactUriQuery } from "vso-node-api/interfaces/WorkItemTrackingInterfaces";

export async function getWorkItemsForGitRepo(vsts: WebApi, baseSourceVersion: string, currentSourceVersion: string, repositoryId: string): Promise<ResourceRef[]> {
    let commitSearchCriteria = <GitQueryCommitsCriteria> {
        $skip: 0,
        $top: 5000,
        includeWorkItems: true,
        itemVersion: { version: baseSourceVersion, versionType: GitVersionType.Commit },
        compareVersion: { version: currentSourceVersion, versionType: GitVersionType.Commit }
    };

    let gitClient = await vsts.getGitApi();
    let commitsBetweenBuilds = await gitClient.getCommitsBatch(commitSearchCriteria, repositoryId);
    let workItems: ResourceRef[] = [];
    commitsBetweenBuilds.forEach(c => workItems.concat(c.workItems));

    return workItems;
}

export async function getWorkItemsForTfvcRepo(vsts: WebApi, changesets: Change[]): Promise<ResourceRef[]> {
    let artifactUris = changesets.map(c => "vstfs:///VersionControl/Changeset/" + c.id);
    let query = <ArtifactUriQuery> {
        artifactUris: artifactUris
    };

    let witClient = await vsts.getWorkItemTrackingApi();
    let artifactWorkItems = await witClient.queryWorkItemsForArtifactUris(query);
    let workItems: ResourceRef[] = [];
    artifactUris.forEach(uri => artifactWorkItems.artifactUrisQueryResult[uri]
        .forEach(ref => workItems.push({id: ref.id.toString(), url: ref.url})));

    return workItems;
}