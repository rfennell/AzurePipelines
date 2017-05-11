import tl = require("vsts-task-lib/task");
import fs = require("fs");
import path = require("path");
var xpath = require('xpath') ,
       dom = require('xmldom').DOMParser;


var filename = tl.getInput("filename");
var xpathQuery = tl.getInput("xpath");
var attribute = tl.getInput("attribute");
var value = tl.getInput("value");
var recurse = new Boolean(tl.getInput("recurse"));

filename = "c:\\tmp\\data*.xml";
recurse = true;
xpathQuery = "/catalog/book[1]/author";
attribute = "";
value = "<SUB>my name aaa</SUB>";

console.log (`Param: filename - ${filename}`);
console.log (`Param: recurse - ${recurse}`);
console.log (`Param: xpath - ${xpathQuery}`);
console.log (`Param: attribute - ${attribute}`);
console.log (`Param: value - ${value}`);

function escapeRegExp(str) {
  return str.replace(/[\-\[\]\/\{\}\(\)\+\?\.\\\^\$\|]/g, "\\$&");
}

// List all files in a directory in Node.js recursively in a synchronous fashion
function findFiles (dir, filenamePattern , recurse, filelist) {
  
  var regex = '^' + escapeRegExp(filenamePattern).replace(/\*/, '.*') + '$';
  var r = new RegExp(regex, 'i'); // make it case insensitive
  var path = path || require('path');
  var fs = fs || require('fs'),

  folderItems = fs.readdirSync(dir);
  filelist = filelist || [];
  folderItems.forEach(function(item) {
    if (fs.statSync(path.join(dir, item)).isDirectory()) {
      // recurse down
      if (recurse === true){
        filelist = findFiles(path.join(dir, item), filenamePattern, recurse, filelist);
      }
    }
    else {
      if (r.test(item))
      {
        filelist.push(path.join(dir, item));
      }
    }
  });
  return filelist;
};

var files = findFiles(path.dirname(filename), path.basename(filename), recurse, files); 

files.forEach(file => {

    var rawContent = fs.readFileSync(file).toString();
    var document = new dom().parseFromString(rawContent);   

    var node = xpath.evaluate( xpathQuery ,document, null, xpath.XPathResult.FIRST_ORDERED_NODE_TYPE, null );
    if (node != null) {
       if ((attribute == null) || (attribute.length ===0))
        {
            node.singleNodeValue.textContent = value;
            console.log(`Updated the file [${file}] with the new value [${xpathQuery}] with the value [${value}]`);
        } else 
        {
            node.singleNodeValue.setAttribute( attribute, value);
            console.log(`Updated the file [${file}] with the new value [${xpathQuery}] with the attribute [${attribute}=${value}]`);
        }
    }
    fs.writeFileSync(file, document);
});