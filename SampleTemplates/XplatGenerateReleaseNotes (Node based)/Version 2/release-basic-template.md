# Release notes 
## Notes for release  ${releaseDetails.releaseDefinition.name}
**Release Number**  : ${releaseDetails.name} 
**Release completed** : ${releaseDetails.modifiedOn} 
**Compared Release Number**  : ${compareReleaseDetails.name} 

### Associated work items  
@@WILOOP@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP@@  
  
### Associated commits
@@CSLOOP@@  
* **ID ${csdetail.id} ** ${csdetail.message}    
@@CSLOOP@@  


