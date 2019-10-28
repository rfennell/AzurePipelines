## Dump of all fields    
**Release**  : ${JSON.stringify(releaseDetails)}     
**Build**: $(JSON.stringify(Build))
**Compared Release**  : ${JSON.stringify(compareReleaseDetails)}    

### All associated work items  
@@WILOOP@@  
* **${JSON.stringify(widetail)}  
@@WILOOP@@  
 
### Associated commits
@@CSLOOP@@  
* ${JSON.stringify(csdetail)}  
@@CSLOOP@@
