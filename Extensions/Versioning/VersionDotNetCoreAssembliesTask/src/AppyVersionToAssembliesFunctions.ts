import fs = require("fs");
import path = require("path");

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

export function stringToBoolean (value: string) {
    switch (value.toLowerCase().trim()) {
        case "true": case "yes": case "1": return true;
        case "false": case "no": case "0": case null: return false;
        default: return Boolean(value);
    }
  }

function UpdateSingleField(file, field, newVersion) {
    var filecontent = fs.readFileSync(file);
    fs.chmodSync(file, "600");
    var tmpField = `<${field}>`;
    if (filecontent.toString().toLowerCase().indexOf(tmpField.toLowerCase()) === -1) {
        console.log (`The ${tmpField} version is not present in the .csproj file so adding it`);
        // add the field, trying to avoid having to load library to parse xml
        // Check for TargetFramework when only using a single framework
        regexp = new RegExp("</TargetFramework>", "g");
        tmpField = tmpField.replace("<", "").replace(">", "");
        if (regexp.exec(filecontent.toString())) {
            console.log (`The ${file} .csproj file only targets 1 framework`);
            var newVersionField = `</TargetFramework><${tmpField}>${newVersion}<\/${tmpField}>`;
            fs.writeFileSync(file, filecontent.toString().replace(`</TargetFramework>`, newVersionField));
        }
        // Check for TargetFrameworks when using multiple frameworks
        regexp = new RegExp("</TargetFrameworks>", "g");
        if (regexp.exec(filecontent.toString())) {
            console.log (`The ${file} .csproj file targets multiple frameworks`);
            var newVersionField1 = `</TargetFrameworks><${tmpField}>${newVersion}<\/${tmpField}>`;
            fs.writeFileSync(file, filecontent.toString().replace(`</TargetFrameworks>`, newVersionField1));
        }
    } else {
        console.log (`Updating only the ${field} version`);
        const csprojVersionRegex = `(<${field}>)(.*)(<\/${field}>)`;
        var regexp = new RegExp(csprojVersionRegex, "gmi");
        let content: string = filecontent.toString();
        let matches;
        while ((matches = regexp.exec(content)) !== null) {
            var existingTag1: string = matches[0];
            console.log(`Existing Tag: ${existingTag1}`);
            var replacementTag1: string = `${matches[1]}${newVersion}${matches[3]}`;
            console.log(`Replacement Tag: ${replacementTag1}`);
            content = content.replace(existingTag1, replacementTag1);
        }
        fs.writeFileSync(file, content);
    }

}

export function ProcessFile(file, field, newVersion, addDefault = false) {

    // Check that the field to update is present
    if (field && field.length > 0) {
        UpdateSingleField(file, field, newVersion);
    } else {
        console.log(`Checking if any version fields to update`);
        var filecontent = fs.readFileSync(file);
        fs.chmodSync(file, "600");
        const csprojVersionRegex = /(<(\w+)?Version>)(.*)(<\/(\w+)?Version>)/gmi;
        let content: string = filecontent.toString();
        let match = csprojVersionRegex.exec(content); // remember each time you call exec it get the next block
        if ( match !== null) {
           do {
                // A match block contains 5 parts (for this regex)
                // 0 - Full match  <Version>1.2.3.4</Version>
                // 1 - Match  <Version>
                // 2 - Match  Version
                // 3 - Match  1.2.3.4
                // 4 - Match  </Version>
                // 5 - Match  Version
                var existingTag: string = match[0];
                console.log(`Existing Tag: ${existingTag}`);
                var replacementTag: string = `${match[1]}${newVersion}${match[4]}`;
                console.log(`Replacement Tag: ${replacementTag}`);
                content = content.replace(existingTag, replacementTag);
            } while ((match = csprojVersionRegex.exec(content)) !== null);
            fs.writeFileSync(file, content);
        } else {
            if (addDefault === true) {
                console.log(`No version field Updating all version fields with ${newVersion}`);
                UpdateSingleField(file, "Version", newVersion);
            }
        }
    }
    console.log (`${file} - version applied`);
}
