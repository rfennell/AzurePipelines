# Release notes for release $defname
**Release Number**  : $($release.name)    
**Release completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$release.modifiedOn) 

**Changes since last successful releases to '$stagename'**   
**Including releases:**   
 $(($releases | select-object -ExpandProperty name) -join ", " )   

## Builds  
@@BUILDLOOP@@
### $($build.definition.name)  
**Build Number**  : $($build.buildnumber)    
**Build completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.finishTime)     
**Source Branch** $($build.sourceBranch)  
  
#### Associated work items  
@@WILOOP@@  
* **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo'.displayName)] $($widetail.fields.'System.Title')  
@@WILOOP@@  
  
#### Associated change sets/commits  
@@CSLOOP@@  
* **ID $($csdetail.changesetid)$($csdetail.commitid)$($csdetail.id)** $($csdetail.comment)    
@@CSLOOP@@  


----------

@@BUILDLOOP@@