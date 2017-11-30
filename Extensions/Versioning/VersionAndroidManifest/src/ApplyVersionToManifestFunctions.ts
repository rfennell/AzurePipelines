import fs = require("fs");
import path = require("path");

export function getVersionName (format, version) {
    const versionNumberSplit = version.split(".");
    const versionNumberMatches = format.match(/\d/g);
    const versionName = versionNumberMatches.join(".");
    return versionName;
}

export function getVersionCode (format, version) {
    const versionCodeSplit = version.split(".");
    const versionCodeMatches = format.match(/\d/g);
    const versionCode = versionCodeMatches.join("");
    return versionCode;
}

export function updateManifestFile (filename, versionCode, versionName) {
    var filecontent = fs.readFileSync(filename).toString();
    fs.chmodSync(filename, "600");
    filecontent = filecontent.replace(/versionCode=\"\d+/g, `versionCode=\"${versionCode}`);
    filecontent = filecontent.replace(/versionName=\"(\d+\.\d+){1,}/g, `versionName=\"${versionName}`);
    fs.writeFileSync(filename, filecontent);
}

// List all files in a directory in Node.js recursively in a synchronous fashion
export function findFiles (dir, filename , filelist) {
    var path = path || require("path");
    var fs = fs || require("fs"),
        files = fs.readdirSync(dir);
    filelist = filelist || [];
    files.forEach(function(file) {
      if (fs.statSync(path.join(dir, file)).isDirectory()) {
        filelist = findFiles(path.join(dir, file), filename, filelist);
      }
      else {
        if (file.toLowerCase().endsWith(filename.toLowerCase())) {
          filelist.push(path.join(dir, file));
        }
      }
    });
    return filelist;
}