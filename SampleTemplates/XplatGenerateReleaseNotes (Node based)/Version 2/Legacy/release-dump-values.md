
# Notes for release dump    
${JSON.stringify(releaseDetails)}    

# The build dump
${JSON.stringify(buildDetails)}    

# The pr dump
${JSON.stringify(prDetails)}    

# All associated work items  
@@WILOOP@@  
* ${JSON.stringify(widetail)}
@@WILOOP@@  
 
# Associated commits dump
@@CSLOOP@@  
* ${JSON.stringify(csdetail)} 
@@CSLOOP@@
