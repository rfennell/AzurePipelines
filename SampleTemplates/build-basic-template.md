#Release notes for build $defname  
**Build Number**  : $($build.buildnumber)    
**Build completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.finishTime)     
**Source Branch** $($build.sourceBranch)  
  
###Associated work items  
@@WILOOP@@  
* **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')] $($widetail.fields.'System.Title')  
@@WILOOP@@  
  
###Associated change sets/commits  
@@CSLOOP@@  
* **ID $($csdetail.changesetid)$($csdetail.commitid)** $($csdetail.comment)    
@@CSLOOP@@  

