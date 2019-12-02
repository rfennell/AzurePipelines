# Release notes 
**Build Number**  : ${buildDetails.buildNumber} 
**Build started** : ${buildDetails.startTime}  
**Source Branch** : ${buildDetails.sourceBranch}  

### Associated work items  
@@WILOOP@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP@@  

### Associated commits
@@CSLOOP@@  
* ** ID ${csdetail.id} ** Commited by:  ${csdetail.author.displayName} (${csdetail.author.uniqueName}) ${csdetail.message}
@@CSLOOP@@