import tl = require("vsts-task-lib/task");
import fs = require("fs");
import path = require("path");
const xpath = require("xpath") ,
    dom = require("xmldom").DOMParser;

const filename = tl.getInput("filename");
const xpathQuery = tl.getInput("xpath");
const attribute = tl.getInput("attribute");
const value = tl.getInput("value");
const recurse = new Boolean(tl.getInput("recurse"));

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
  const regex = "^" + escapeRegExp(filenamePattern).replace(/\*/, ".*") + "$";
  const r = new RegExp(regex, "i"); // make it case insensitive
  // let path = path || require('path');
  // let fs = fs || require('fs'),

  const folderItems = fs.readdirSync(dir);
  filelist = filelist || [];
  folderItems.forEach(function(item) {
    if (fs.statSync(path.join(dir, item)).isDirectory()) {
       // recurse down
       if (recurse === true) {
          filelist = findFiles(path.join(dir, item), filenamePattern, recurse, filelist);
       }
    }
    else {
      if (r.test(item)) {
        filelist.push(path.join(dir, item));
      }
    }
  });
  return filelist;
}

let files;
findFiles(path.dirname(filename), path.basename(filename), recurse, files);

files.forEach(file => {

    let rawContent = fs.readFileSync(file).toString();
    let document = new dom().parseFromString(rawContent);

    let node = xpath.evaluate( xpathQuery , document, null, xpath.XPathResult.FIRST_ORDERED_NODE_TYPE, null );
    if (node != null) {
       if ((attribute == null) || (attribute.length === 0)) {
            node.singleNodeValue.textContent = value;
            console.log(`Updated the file [${file}] with the new value [${xpathQuery}] with the value [${value}]`);
        } else {
            node.singleNodeValue.setAttribute( attribute, value);
            console.log(`Updated the file [${file}] with the new value [${xpathQuery}] with the attribute [${attribute}=${value}]`);
        }
    }
    fs.writeFileSync(file, document);
});