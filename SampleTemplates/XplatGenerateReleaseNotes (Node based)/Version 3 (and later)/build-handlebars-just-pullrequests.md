# {{buildDetails.definition.name}} {{buildDetails.buildNumber}}
* **Branch**: {{buildDetails.sourceBranch}}
* **Tags**: {{buildDetails.tags}}
* **Completed**: {{buildDetails.finishTime}}

## Associated Pull Requests
{{#forEach pullRequests}}
* **[{{this.pullRequestId}}]({{replace (replace this.url "_apis/git/repositories" "_git") "pullRequests" "pullRequest"}})** {{this.title}}
* Created by {{this.createdBy.displayName}}  {{thos.creationDate}}
* Reviewed by:
{{#forEach this.reviewers}}
  * {{this.displayName}}
{{/forEach}}
* Associated Work Items
{{#each_with_sort_by_field  this.associatedWorkitems "System.Tags"}}
   {{#with (lookup_a_work_item ../../relatedWorkItems this.url)}}
    - [{{this.id}}]({{replace this.url "_apis/wit/workItems" "_workitems/edit"}}) - {{lookup this.fields 'System.Title'}}
   {{/with}}
{{/each_with_sort_by_field}}
* Associated Commits (this includes commits on the PR source branch not associated directly with the build)
{{#forEach this.associatedCommits}}
    - [{{truncate this.commitId 7}}]({{this.remoteUrl}}) - {{get_only_message_firstline this.comment}}
    {{#with (lookup_a_pullrequest_by_merge_commit ../../inDirectlyAssociatedPullRequests  this.commitId)}}
      - Associated PR {{this.pullRequestId}} - {{this.title}}
    {{/with}}
{{/forEach}}
{{/forEach}}

