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

export function ProcessFile(file, field, newVersion) {
  
    var filecontent = fs.readFileSync(file);
    fs.chmodSync(file, "600");

    // Check that the field to update is present
    var tmpField = "<Version>";
    if (field && field.length > 0) {
        tmpField = `<${field}>`;
    }

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
        if (field && field.length > 0) {
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

        } else {
            console.log(`Updating all version fields with ${newVersion}`);
            const csprojVersionRegex = /(<\w+Version>)(.*)(<\/\w+Version>)/gmi;
            let content: string = filecontent.toString();
            let matches;
            while ((matches = csprojVersionRegex.exec(content)) !== null) {
                var existingTag: string = matches[0];
                console.log(`Existing Tag: ${existingTag}`);
                var replacementTag: string = `${matches[1]}${newVersion}${matches[3]}`;
                console.log(`Replacement Tag: ${replacementTag}`);
                content = content.replace(existingTag, replacementTag);
            }
            fs.writeFileSync(file, content);
        }
        console.log (`${file} - version applied`);
    }
}