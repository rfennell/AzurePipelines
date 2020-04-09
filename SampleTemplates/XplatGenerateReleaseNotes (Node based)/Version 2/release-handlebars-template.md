## Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number**: {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}    
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 
**PR Details**: {{prDetails.title}}

##  All Associated Work Items ({{workItems.length}})
{{#forEach workItems}}
{{#if isFirst}}### Associated Work Items (only shown if  WI) {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/forEach}}

##  Associated Work Items with Tag1
{{#forEach workItems}}
{{#if (test (lookup this.fields 'System.Tags') (toRegex 'Tag 1')) }}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/if }}
{{/forEach}}


## Associated commits  ({{commits.length}})
{{#forEach commits}}
{{#if isFirst}}### Associated commits  (only shown if CS) {{/if}}
* ** ID{{this.id}}** 
   -  **Message:** {{this.message}}
   -  **Commited by:** {{this.author.displayName}} 
{{/forEach}}
