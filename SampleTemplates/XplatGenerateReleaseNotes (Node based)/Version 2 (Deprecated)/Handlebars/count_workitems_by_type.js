// A Handlebars Helper to count the number of work items of a given type
/* Usage
- Total WI {{this.workItems.length}}
- Bugs {{count_workitems_by_type this.workItems "Bug"}} 
- Product Backlog Item {{count_workitems_by_type this.workItems "Product Backlog Item"}} 
*/

module.exports = {count_workitems_by_type(array, typeName) {
    return array.filter(wi => wi.fields['System.WorkItemType'] === typeName).length;}
};