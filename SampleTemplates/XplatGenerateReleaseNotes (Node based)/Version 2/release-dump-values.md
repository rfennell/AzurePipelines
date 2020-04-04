## Dump of all fields    
**Release**  : ${JSON.stringify(releaseDetails)}     
**Build**: $(JSON.stringify(Build))
**Compared Release**  : ${JSON.stringify(compareReleaseDetails)}   
**PR Title** : ${JSON.stringify(prDetails)}

### All associated work items  
@@WILOOP@@  
* **${JSON.stringify(widetail)}  
@@WILOOP@@  
 
### Associated commits
@@CSLOOP@@  
* ${JSON.stringify(csdetail)}  
@@CSLOOP@@
