// A Handlebars Helper to sort an array of WI based on a field name
/* Usage
#  Sort ID
    {{#each_with_sort_by_field  this.workItems "System.Id"}}
    {{#if isFirst}}### WorkItems {{/if}}
    *  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
    - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
    - **Tags** {{lookup this.fields 'System.Tags'}}
    {{/each_with_sort_by_field}} 

    #  Sort title
    {{#each_with_sort_by_field  this.workItems "System.Title"}}
    {{#if isFirst}}### WorkItems {{/if}}
    *  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
    - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
    - **Tags** {{lookup this.fields 'System.Tags'}}
    {{/each_with_sort_by_field}}
*/


const handlebars = require("handlebars");
module.exports = {each_with_sort_by_field: function (array, key, opts) {
    if(opts.data) {
        data  = handlebars.createFrame(opts.data) 
    }

    // the sort
    array = array.sort (function (a, b) {
        a = a.fields[key]
        b = b.fields[key]
        if (a > b) return 1 
        if (a == b) return 0
        if (a < b) return -1
    });

    // the iterator
    var len = array.length;
    var buffer = '';
    var i = -1;
  
    while (++i < len) {
      var item = array[i];
      data.index = i;
      item.index = i + 1;
      item.total = len;
      item.isFirst = i === 0;
      item.isLast = i === (len - 1);
      buffer += opts.fn(item, {data: data});
    }
    return buffer;
}}