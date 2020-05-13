# Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number**: {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}    
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 

# Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
{{#if isFirst}}### Associated Pull Requests (only shown if  PR) {{/if}}
*  **PR {{this.id}}**  {{this.title}}
{{/forEach}}

# Builds with associated WI/CS ({{builds.length}})
{{#forEach builds}}
{{#if isFirst}}## Builds {{/if}}
##  Build {{this.build.buildNumber}}
{{#forEach this.commits}}
{{#if isFirst}}### Commits {{/if}}
- CS {{this.id}}
{{/forEach}}
{{#forEach this.workitems}}
{{#if isFirst}}### Workitems {{/if}}
- WI {{this.id}}
{{/forEach}} 
{{/forEach}}

# Global list of WI ({{workItems.length}})
{{#forEach workItems}}
{{#if isFirst}}## Associated Work Items (only shown if  WI) {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/forEach}}

# WI with 'Tag 1'
{{#forEach this.workItems}}
{{#if isFirst}}### WorkItems with 'Tag 1'{{/if}}
{{#if (contains (lookup this.fields 'System.Tags') 'Tag 1')}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/if}}
{{/forEach}} 

# WI with 'Tag 1' or 'TAG1'
{{#forEach this.workItems}}
{{#if isFirst}}### WorkItems with 'Tag 1' or 'TAG2'{{/if}}
{{#if (or (contains (lookup this.fields 'System.Tags') 'Tag 1') (contains (lookup this.fields 'System.Tags') 'TAG2'))}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/if}}
{{/forEach}} 

# WI with 'Tag 1' and 'TAG1'
{{#forEach this.workItems}}
{{#if isFirst}}### WorkItems with 'Tag 1' and 'TAG2'{{/if}}
{{#if (and (contains (lookup this.fields 'System.Tags') 'Tag 1') (contains (lookup this.fields 'System.Tags') 'TAG2'))}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/if}}
{{/forEach}} 

# Global list of CS ({{commits.length}})
{{#forEach commits}}
{{#if isFirst}}### Associated commits  (only shown if CS) {{/if}}
* ** ID{{this.id}}** 
   -  **Message:** {{this.message}}
   -  **Commited by:** {{this.author.displayName}} 
{{/forEach}}
