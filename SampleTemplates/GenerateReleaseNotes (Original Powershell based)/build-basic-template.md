# Release notes for build $defname  
**Build Number**  : $($build.buildnumber) 
**Build Configuration** :  $($build.parameters | ConvertFrom-Json | select -ExpandProperty BuildConfiguration )
**Build started** : $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)  
**Source Branch** $($build.sourceBranch)  
  
## Associated work items  
@@WILOOP@@  
* **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo'.displayName)] $($widetail.fields.'System.Title')  
@@WILOOP@@  
  
## Associated change sets/commits  
@@CSLOOP@@  
* **ID $($csdetail.changesetid)$($csdetail.commitid)** $($csdetail.comment)    
@@CSLOOP@@  

