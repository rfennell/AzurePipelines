"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs = require("fs");
const path = require("path");
const xpath = require("xpath");
const xmldom = require("xmldom");
function escapeRegExp(str) {
    return str.replace(/[\-\[\]\/\{\}\(\)\+\?\.\\\^\$\|]/g, "\\$&");
}
// List all files in a directory in Node.js recursively in a synchronous fashion
function findFiles(dir, filenamePattern, recurse, filelist) {
    const regex = "^" + escapeRegExp(filenamePattern).replace(/\*/, ".*") + "$";
    const r = new RegExp(regex, "i"); // make it case insensitive
    // let path = path || require('path');
    // let fs = fs || require('fs'),
    const folderItems = fs.readdirSync(dir);
    filelist = filelist || [];
    folderItems.forEach(function (item) {
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
exports.findFiles = findFiles;
function processFile(xpathQuery, file, rawContent, value, attribute, logFunction) {
    const dom = xmldom.DOMParser;
    let document = new dom().parseFromString(rawContent);
    //  XPathResult.FIRST_ORDERED_NODE_TYPE using int equiv 9 else build transpile issue
    let xmlNode = xpath.evaluate(xpathQuery, document, null, 9, null);
    if (xmlNode != null) {
        if ((attribute == null) || (attribute.length === 0)) {
            xmlNode.singleNodeValue.textContent = value;
            logFunction(`Updated the file [${file}] with the new value [${xpathQuery}] with the value [${value}]`);
        }
        else {
            xmlNode.singleNodeValue.attributes.getNamedItem(attribute).textContent = value;
            logFunction(`Updated the file [${file}] with the new value [${xpathQuery}] with the attribute [${attribute}=${value}]`);
        }
    }
    return document;
}
exports.processFile = processFile;
//# sourceMappingURL=FileUpdateFunctions.js.map