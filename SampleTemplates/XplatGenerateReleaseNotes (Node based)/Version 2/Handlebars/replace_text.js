// A Handlebars Helper to replace some text value with another
/* Usage
- {{replace_text this.message 'fix:' '* Fixed'}} 
*/

module.exports = {replace_text(msg, match, replacement) {
    return msg.replace(match, replacement);}
};