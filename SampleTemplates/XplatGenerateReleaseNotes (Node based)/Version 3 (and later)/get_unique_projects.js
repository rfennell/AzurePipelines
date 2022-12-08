// A Handlebars Helper to extra the project name from a full file path
// only listing unique projects. 
// This is a very rough implementation, but should act as a sample

/* Usage
- {{get_unique_projects <array of Git Changes> <index of project name block in path>}} 

# Global list of CS ({{commits.length}})
{{#forEach commits}}
* **SHA** {{this.id}} **FileCount:** {{this.changes.length}} **in Projects**
{{get_unique_projects this.changes 3}}  
{{/forEach}}
*/

module.exports = {
    get_unique_projects(array, depthIndex) {
        var output = ''; 
        var seenItems = []; 
        for (let i = 0; i < array.length; i++) {
            parts = array[i].item.path.split('/'); 
            if (array[i].item.isFolder && parts.length > depthIndex && !seenItems.includes(parts[depthIndex])) {
                seenItems.push(parts[depthIndex]); 
                output += '  - ' + parts[depthIndex] + '\\r\\n'
            }
        }; 
        return output 
    }
};