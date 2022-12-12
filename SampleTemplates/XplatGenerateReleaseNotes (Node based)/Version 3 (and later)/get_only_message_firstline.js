// A Handlebars Helper to get just the first line of a multi-line string
// Useful if you only want the title from a multi-line commit message
/* Usage
## Global list of CS ({{commits.length}})
{{#forEach commits}}
* **{{truncate this.id 7}}** {{get_only_message_firstline this.message}}
{{/forEach}}
*/

module.exports = {
    get_only_message_firstline(msg) {
       return msg.split(`\n`)[0]
    }
};