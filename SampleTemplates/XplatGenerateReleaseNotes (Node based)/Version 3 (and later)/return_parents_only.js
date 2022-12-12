// A Handlebars Helper to list just the parents of associated workitems
/* Usage
# Just Parents
{{#return_parents_only this.workItems this.relatedWorkItems}}
  - {{this.id}} - {{lookup this.fields 'System.Title'}} 
{{/return_parents_only}} 
*/

module.exports = {
    return_parents_only(array, relatedWorkItems, block) {
        var ret = ''; 
        var foundList = [];
        for (var arrayCount = 0; arrayCount < array.length ; arrayCount++) {
             for (var relationCount = 0; relationCount < array[arrayCount].relations.length; relationCount++) { 
                if (array[arrayCount].relations[relationCount].attributes.name == 'Parent') { 
                    var urlParts = array[arrayCount].relations[relationCount].url.split("/");
                    var id = parseInt(urlParts[urlParts.length - 1]);
                    var parent = relatedWorkItems.find(element => element.id === id);
                    if (!foundList.includes(parent)) {
                        foundList.push(parent);
                        ret += block.fn(parent);
                    }
                }
            }
        }; 
        return ret;
    }
}