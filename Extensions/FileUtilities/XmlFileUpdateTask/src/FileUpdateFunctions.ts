import fs = require("fs");
import path = require("path");
import xpath = require("xpath");
import xmldom = require("xmldom");

function escapeRegExp(str) {
  return str.replace(/[\-\[\]\/\{\}\(\)\+\?\.\\\^\$\|]/g, "\\$&");
}

export function processFiles (filename, recurse, xpathQuery, value, attribute, logInfo, logDebug ) {
  let files;
  logDebug (`Looking in folder [${path.dirname(filename)}] for files that match pattern [${path.basename(filename)}] using recursion [${recurse}]`);

  files = findFiles(path.dirname(filename), path.basename(filename), recurse, files);

  files.forEach(file => {
      let rawContent = fs.readFileSync(file).toString();
      let document = processFile(xpathQuery, file, rawContent, value, attribute, logInfo);
      fs.writeFileSync(file, document);
  });
}

// List all files in a directory in Node.js recursively in a synchronous fashion
export function findFiles (dir, filenamePattern, recurse, filelist): any {

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

export function processFile(xpathQuery, file, rawContent, value, attribute, logFunction): any {
  const dom = xmldom.DOMParser;

  let document = new dom().parseFromString(rawContent);

  //  XPathResult.FIRST_ORDERED_NODE_TYPE using int equiv 9 else build transpile issue
  let xmlNode = xpath.evaluate( xpathQuery , document, null, 9, null );
  if (xmlNode != null) {
     if ((attribute == null) || (attribute.length === 0)) {
          xmlNode.singleNodeValue.textContent = value;
          logFunction(`Updated the file [${file}] with the new value [${xpathQuery}] with the value [${value}]`);
      } else {
          xmlNode.singleNodeValue.attributes.getNamedItem(attribute).textContent = value;
          logFunction(`Updated the file [${file}] with the new value [${xpathQuery}] with the attribute [${attribute}=${value}]`);
      }
  }
  return document;

}