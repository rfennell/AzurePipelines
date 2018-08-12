import fs = require("fs");
import path = require("path");
import tl = require("vsts-task-lib/task");

export function extractVersion(injectversion, versionRegex, versionNumber ) {
    var newVersion = versionNumber;
    if (injectversion === false) {
        var regexp = new RegExp(versionRegex);
        var versionData = regexp.exec(versionNumber);
        if (!versionData) {
            // extra check as we don't get zero size array but a null
            tl.error(`Could not find version number data in ${versionNumber} that matches ${versionRegex}.`);
            process.exit(1);
        }
        switch (versionData.length) {
        case 0:
                // this is trapped by the null check above
                tl.error(`Could not find version number data in ${versionNumber} that matches ${versionRegex}.`);
                process.exit(1);
        case 1:
                break;
        default:
                tl.warning(`Found more than instance of version data in ${versionNumber}  that matches ${versionRegex}.`);
                tl.warning(`Will assume first instance is version.`);
                break;
        }

        newVersion = versionData[0];
    }
    return newVersion;
}

export function getSplitVersionParts (buildNumberFormat, outputFormat, version) {
    const versionNumberSplitItems = version.split(extractDelimitersRegex(buildNumberFormat));
    const versionNumberMatches = outputFormat.match(/\d/g);
    const joinChar =  extractJoinChar(outputFormat);
    const versionName = (versionNumberMatches.map((item) => versionNumberSplitItems[item - 1])).join(joinChar);
    return versionName;
}

function extractJoinChar(format) {
    const delimiters = format.replace(/{\d}/g, "");
    if (delimiters) {
        return delimiters[0];
    } else {
        return "";
    }
}

function extractDelimitersRegex(format) {
    const delimiters = format.replace(/[\\d+\\]/g, "");
    return (new RegExp("[" + delimiters + "]"));
}

export function updateManifestFile (filename, versionCode, versionName) {
    var filecontent = fs.readFileSync(filename).toString();
    fs.chmodSync(filename, "600");
    filecontent = filecontent.replace(/versionCode=\"([^"]*)\"/g, `versionCode=\"${versionCode}\"`);
    filecontent = filecontent.replace(/versionName=\"([^"]*)\"/g, `versionName=\"${versionName}\"`);
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