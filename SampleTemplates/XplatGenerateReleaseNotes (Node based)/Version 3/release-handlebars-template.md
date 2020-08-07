# Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number**: {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}    
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 

# Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
{{#if isFirst}}### Associated Pull Requests (only shown if  PR) {{/if}}
*  **{{this.pullRequestId}}** {{this.title}}
{{/forEach}}

# Builds with associated WI/CS ({{builds.length}})
{{#forEach builds}}
{{#if isFirst}}## Builds {{/if}}
-  Build {{this.build.buildNumber}}
{{#forEach this.commits}}
   - CS {{this.id}}
      - **Message:** {{this.message}}
{{/forEach}}
{{#forEach this.workitems}}
   - WI {{this.id}}
      - **Title** {{lookup this.fields 'System.Title'}}
{{/forEach}} 
{{#forEach this.tests}}
   - Test {{this.id}} 
      -  **Name** {{this.testCase.name}}
      -  **Outcome** {{this.outcome}}
{{/forEach}} 
{{/forEach}}

# Global list of WI ({{workItems.length}})
{{#forEach workItems}}
{{#if isFirst}}## Associated Work Items (only shown if  WI) {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
   - **Assigned** {{#with (lookup this.fields 'System.AssignedTo')}} {{displayName}} {{/with}}
{{/forEach}}

# Global list of WI with parents and children
{{#forEach this.workItems}}
{{#if isFirst}}### WorkItems {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
   - **Assigned** {{#with (lookup this.fields 'System.AssignedTo')}} {{displayName}} {{/with}}
   - **Description** {{{lookup this.fields 'System.Description'}}}
   - **Parents**
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Parent')}}
{{#with (lookup_a_work_item ../../relatedWorkItems  this.url)}}
      - {{this.id}} - {{lookup this.fields 'System.Title'}} 
{{/with}}
{{/if}}
{{/forEach}} 
   - **Children**
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Child')}}
{{#with (lookup_a_work_item ../../relatedWorkItems  this.url)}}
      - {{this.id}} - {{lookup this.fields 'System.Title'}} 
{{/with}}
{{/if}}
{{/forEach}} 
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
{{#if isFirst}}### Associated commits{{/if}}
* ** ID{{this.id}}** 
   -  **Message:** {{this.message}}
   -  **Commited by:** {{this.author.displayName}} 
   -  **FileCount:** {{this.changes.length}} 
{{#forEach this.changes}}
      -  **File path (TFVC or TfsGit):** {{this.item.path}}  
      -  **File filename (GitHub):** {{this.filename}}  
{{/forEach}}
{{/forEach}}


# Global list of test ({{tests.length}})
{{#forEach tests}}
{{#if isFirst}}### Tests {{/if}}
* ** ID{{this.id}}** 
   -  Name: {{this.testCase.name}}
   -  Outcome: {{this.outcome}}
{{/forEach}}