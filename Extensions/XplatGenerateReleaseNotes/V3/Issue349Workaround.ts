import * as tl from "azure-pipelines-task-lib";
import { WebApi } from "azure-devops-node-api/WebApi";
import { ResourceRef } from "azure-devops-node-api/interfaces/common/VSSInterfaces";
import { GitQueryCommitsCriteria, GitVersionType } from "azure-devops-node-api/interfaces/GitInterfaces";
import { Change } from "azure-devops-node-api/interfaces/BuildInterfaces";
import { ArtifactUriQuery } from "azure-devops-node-api/interfaces/WorkItemTrackingInterfaces";

export async function getCommitsAndWorkItemsForGitRepo(vsts: WebApi, baseSourceVersion: string, currentSourceVersion: string, repositoryId: string): Promise<CommitInfo> {
    let maxCommits = tl.getVariable("ReleaseNotes.Fix349.MaxCommits") ? Number(tl.getVariable("ReleaseNotes.Fix349.MaxCommits")) : 5000;
    let maxWorkItems = tl.getVariable("ReleaseNotes.Fix349.MaxWorkItems") ? Number(tl.getVariable("ReleaseNotes.Fix349.MaxWorkItems")) : 5000;

    let commitSearchCriteria = <GitQueryCommitsCriteria> {
        $skip: 0,
        $top: maxCommits,
        includeWorkItems: true,
        itemVersion: { version: baseSourceVersion, versionType: GitVersionType.Commit },
        compareVersion: { version: currentSourceVersion, versionType: GitVersionType.Commit }
    };

    let gitClient = await vsts.getGitApi();
    let commitsBetweenBuilds = await gitClient.getCommitsBatch(commitSearchCriteria, repositoryId, null, 0, maxCommits);

    let workItems: ResourceRef[] = [];
    let commits: Change[] = [];
    commitsBetweenBuilds.forEach(c => {
        commits.push(<Change>{
            id: c.commitId,
            message: c.comment,
            messageTruncated: c.commentTruncated,
            type: "TfsGit",
            author: {
                displayName: c.author.name,
                id: null,
                uniqueName: c.committer.email
            },
            timestamp: c.author.date,
            location: c.url
            // pusher is missing from the result - do we need that?
        });
        let index = 0;
        while (index < c.workItems.length && workItems.length < maxWorkItems) {
            workItems.push(c.workItems[index++]);
        }
    });

    return {
        commits: commits,
        workItems: workItems
    };
}

export interface CommitInfo {
    commits: Change[];
    workItems: ResourceRef[];
}
