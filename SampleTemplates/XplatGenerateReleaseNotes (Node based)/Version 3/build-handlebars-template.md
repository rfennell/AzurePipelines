# Notes for build 
**Build Number**: {{buildDetails.id}}
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 

# Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
{{#if isFirst}}### Associated Pull Requests (only shown if  PR) {{/if}}
*  **{{this.pullRequestId}}** {{this.title}}
{{/forEach}}

# Global list of WI ({{workItems.length}})
{{#forEach workItems}}
{{#if isFirst}}## Associated Work Items (only shown if  WI) {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
  - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
  - **Tags** {{lookup this.fields 'System.Tags'}}
  - **Assigned** {{#with (lookup this.fields 'System.AssignedTo')}} {{displayName}} {{/with}}
{{/forEach}}

# Global list of CS ({{commits.length}})
{{#forEach commits}}
{{#if isFirst}}### Associated commits  (only shown if CS) {{/if}}
* ** ID{{this.id}}** 
  -  **Message:** {{this.message}}
  -  **Commited by:** {{this.author.displayName}} 
{{/forEach}}

## Global list of ConsumedArtifacts ({{consumedArtifacts.length}})
| Category | Type | Version Name | Version Id | Commits | Workitems |
|-|-|-|-|-|-|
{{#forEach consumedArtifacts}}
 |{{this.artifactCategory}} | {{this.artifactType}} | {{#if versionName}}{{versionName}}{{/if}} | {{truncate versionId 7}} | {{#if this.commits}} {{this.commits.length}} {{/if}} | {{#if this.workitems}} {{this.workitems.length}} {{/if}} |
{{/forEach}}