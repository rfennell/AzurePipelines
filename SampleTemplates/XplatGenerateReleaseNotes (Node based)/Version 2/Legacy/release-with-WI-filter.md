## Notes for release  ${releaseDetails.releaseDefinition.name}    
**Release Number**  : ${releaseDetails.name}    
**Release completed** : ${releaseDetails.modifiedOn}     
**Compared Release Number**  : ${compareReleaseDetails.name}    

### All associated work items  
@@WILOOP@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP@@  

### Associated work items with 'Tag 1' 
@@WILOOP:TAG 1@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP:TAG 1@@  

### Associated work items with 'Tag 1' and 'Tag 2' legacy format 
@@WILOOP:TAG 1:TAG2@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP:TAG 1:TAG2@@    

### Associated work items with 'Tag 1' and 'Tag 2' new format loop format 
@@WILOOP[ALL]:TAG 1:TAG2@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP[ALL]:TAG 1:TAG2@@  

### Associated work items with and either of the 'Tag 1' or 'Tag 2' new lop format 
@@WILOOP[ANY]:TAG 1:TAG2@@  
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}  
@@WILOOP[ANY]:TAG 1:TAG2@@  

### Associated work items that have the title 'This is a title' or the tag 'Tage'
@@WILOOP[ALL]:System.Title=This is a title:TAG 1@@  
* **${widetail.fields['System.WorkItemType']} ${widetail.id}** ${widetail.fields['System.Title']}  
@@WILOOP:TAG 1@@  

### Associated commits
@@CSLOOP@@  
* ** ID ${csdetail.id} ** ${csdetail.message}    
@@CSLOOP@@
