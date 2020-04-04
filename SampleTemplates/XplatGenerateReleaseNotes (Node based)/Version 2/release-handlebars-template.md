## Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number**: {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}  
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 
**PR Details**: {{prDetails.title}}


### Associated Work Items ({{workItems.length}})

{{#each workItems}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
{{/each}}

### Associated commits ({{commits.length}})
{{#each commits}}
* ** ID{{this.id}}** 
   -  **Message:** {{this.message}}
   -  **Commited by:** {{this.author.displayName}} 
{{/each}}
