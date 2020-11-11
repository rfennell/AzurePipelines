# Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number** : {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}    
**Build Trigger PR Number** : {{lookup buildDetails.triggerInfo 'pr.number'}} 

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
   - **Desc** {{{lookup this.fields 'System.Description'}}}
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
      - {{this.id}} - {{{lookup this.fields 'Custom.Notesdeversion'}}} 
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

# Changes
{{#forEach commits}}
{{#if isFirst}}### Associated commits{{/if}}

{{#startsWith "Merge " this.message}}
{{else}}
* **Message:** {{this.message}}  
   -  **Commited by:** {{this.author.displayName}} 
{{/startsWith}}
   
{{/forEach}}



