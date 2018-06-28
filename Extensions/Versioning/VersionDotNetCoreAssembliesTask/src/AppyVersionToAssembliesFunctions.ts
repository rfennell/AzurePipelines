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
            var filecontent = fs.readFileSync(path.join(dir, file));
            if (filecontent.toString().toLowerCase().indexOf("<project sdk=\"microsoft.net.sdk") === -1) {
                console.log(`Skipping file ${file} as is not a .NETCore Project`);
            } else {
                console.log(`Adding file ${file} as is a .NETCore Project`);
                filelist.push(path.join(dir, file));
            }
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
    var isVersionApplied: any = false;
    // Check that the field to update is present
    if (field && field.length > 0) {
        UpdateSingleField(file, field, newVersion);
        isVersionApplied = true;
    } else {
        console.log(`Checking if any version fields to update`);
        var filecontent = fs.readFileSync(file);
        fs.chmodSync(file, "600");
        // We only need to consider the following fields
        let versionFields = ["Version", "VersionPrefix", "AssemblyVersion"];
        let content: string = filecontent.toString();
        var hasUpdateFields: any = false;
        versionFields.forEach(element => {
            console.log(`Processing Field ${element}`);
            const csprojVersionRegex = `(<${element}>)(.*)(<\/${element}>)`;
            var regexp = new RegExp(csprojVersionRegex, "gmi");
            let matches;
            while ((matches = regexp.exec(content)) !== null) {
                var existingTag1: string = matches[0];
                console.log(`Existing Tag: ${existingTag1}`);
                var replacementTag1: string = `${matches[1]}${newVersion}${matches[3]}`;
                console.log(`Replacement Tag: ${replacementTag1}`);
                content = content.replace(existingTag1, replacementTag1);
                hasUpdateFields = true;
            }
        });
        if (hasUpdateFields === true) {
            fs.writeFileSync(file, content);
            isVersionApplied = true;
        } else {
            if (addDefault === true) {
                console.log(`No version fields present, so add a Version field`);
                UpdateSingleField(file, "Version", newVersion);
                isVersionApplied = true;
            } else {
                console.log(`No version fields present, version field ignored because 'addDefault' is false`);
            }
        }
    }
    if (isVersionApplied) {
        console.log (`${file} - version applied`);
    } else {
        console.log (`${file} - version not applied`);
    }
}
