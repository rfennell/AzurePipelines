#Release notes for build $defname  
**build**: $($build)   


***Note** that if the is a single associated item then then size is empty, but the item is returned  
If there are multiple associated items then the size is >0  but you need to use an index to see each item*   
**workitems:** [Size $($workitems.length)] $($workitems)     
**workitems:** [Size $($workitems.length)] $($workitems[0])     

**changesets:**[Size $($changesets.length)] $($changesets)     
**changesets:**[Size $($changesets.length)] $($changesets[0])  
  
###Associated work items (Dump of all fields)  
@@WILOOP@@  
* **widetail:** $($widetail)
* **widetail.fields:** $($widetail.fields)  
* **widetail.links:** $($widetail.fields)  
@@WILOOP@@  
  
###Associated change sets/commits (Dump of all fields) 
@@CSLOOP@@  
* **csdetail:** $($csdetail)    
@@CSLOOP@@  