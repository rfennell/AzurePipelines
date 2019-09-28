import fs = require("fs");
import path = require("path");
import tl = require("vsts-task-lib/task");

export function extractVersion(injectversion, versionRegex, versionNumber ) {
    var newVersion = versionNumber;
    if (injectversion === false) {
        console.log(`Extracting version number from build number`);
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
    } else {
        console.log(`Using provided version number directly`);
    }
    return newVersion;
}

export function SplitSDKName(sdkstring) {
    var array = [];
    if (sdkstring.length > 0) {
        array = sdkstring.trim().split(",").map(item => item.trim());
    }
    return array;
}

// List all files in a directory in Node.js recursively in a synchronous fashion
export function findFiles (dir, filename , filelist, sdknames: string[]) {
    var path = path || require("path");
    var fs = fs || require("fs"),
        files = fs.readdirSync(dir);
    filelist = filelist || [];
    if (sdknames.length === 0 ) {
        console.log (`No SDK Name passed, so cannot match files`);
    } else {
        files.forEach(function(file) {
            if (fs.statSync(path.join(dir, file)).isDirectory()) {
                filelist = findFiles(path.join(dir, file), filename, filelist, sdknames);
            }
            else {
                if (file.toLowerCase().endsWith(filename.toLowerCase())) {
                    var filecontent = fs.readFileSync(path.join(dir, file));
                    var matchingSDK = false;
                    let count = sdknames.length;
                    // need to use a for loop to allow break, not the most elegent solution
                    for (let i = 0; i < count; i++) {
                        if (filecontent.toString().toLowerCase().indexOf(`<project sdk=\"${sdknames[i].toLowerCase()}`) !== -1) {
                            console.log(`Matched the file '${file}' using the SDK name '${sdknames[i]}'`);
                            matchingSDK = true;
                            break;
                        }
                    }
                    if (matchingSDK) {
                        console.log(`Adding file ${file} as is a .NETCore Project`);
                        filelist.push(path.join(dir, file));
                    } else {
                        console.log(`Skipping file ${file} as is not a .NETCore Project`);
                    }
                }
            }
        });
    }
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
    let content: string = filecontent.toString();
    fs.chmodSync(file, "600");

    console.log (`Getting just the PropertyGroup that contains the version fields`);
    const propertyGroupRegex = new RegExp(/<PropertyGroup>([\s\S]*?)<\/PropertyGroup>/gmi);
    var propertyGroupMatches = propertyGroupRegex.exec(content);
    // we assume the first property group we find is the correct one
    if (propertyGroupMatches === null) {
        console.log(`Cannot find any <PropertyGroup> blocks so adding one`);
        var insertPropertyGroupText = `<PropertyGroup><${field}>${newVersion}<\/${field}></PropertyGroup></Project>`;
        fs.writeFileSync(file, filecontent.toString().replace("</Project>", insertPropertyGroupText));
    } else {
        console.log(`Found <PropertyGroup> block`);
        var propertyGroupText = propertyGroupMatches[0];
        var tmpField = `<${field}>`;
        var newPropertyGroupText = "";
        if (propertyGroupText.toString().toLowerCase().indexOf(tmpField.toLowerCase()) === -1) {
            console.log (`The ${tmpField} version is not present in the .csproj file so adding it`);
            // add the field, trying to avoid having to load library to parse xml
            // Check for TargetFramework when only using a single framework
            var regexp = new RegExp("</TargetFramework>", "gi");
            tmpField = tmpField.replace("<", "").replace(">", "");
            if (regexp.exec(propertyGroupText.toString())) {
                console.log (`The ${file} .csproj file only targets 1 framework`);
                var newVersionField = `</TargetFramework><${tmpField}>${newVersion}<\/${tmpField}>`;
                newPropertyGroupText = propertyGroupText.replace(`</TargetFramework>`, newVersionField);
                fs.writeFileSync(file, filecontent.toString().replace(propertyGroupText, newPropertyGroupText));
            }
        } else {
            console.log (`Updating only the ${field} version`);

            const fieldRegex = `(<${field}>)(.*)(<\/${field}>)`;
            var fieldRegexp = new RegExp(fieldRegex, "gi");
            var matches = fieldRegexp.exec(propertyGroupText);
            if (matches !== null) {
                var existingTag1: string = matches[0];
                console.log(`Existing Tag: ${existingTag1}`);
                var replacementTag1: string = `${matches[1]}${newVersion}${matches[3]}`;
                console.log(`Replacement Tag: ${replacementTag1}`);
                newPropertyGroupText = propertyGroupText.replace(existingTag1, replacementTag1);
            }
            var updateFileContents = content.replace(propertyGroupText, newPropertyGroupText);
            fs.writeFileSync(file, updateFileContents);
        }
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
        let content: string = filecontent.toString();
        fs.chmodSync(file, "600");
        // We only need to consider the following fields in the main PropertyGroup block
        console.log (`Getting just the PropertyGroup that contains the version fields`);
        const propertyGroupRegex = new RegExp(/<PropertyGroup>([\s\S]*?)<\/PropertyGroup>/gmi);
        var matches = propertyGroupRegex.exec(content);
        // we assume the first property group we find is the correct one
        var propertyGroupText = "<PropertyGroup></PropertyGroup>";
        if (matches === null) {
            console.log(`Cannot find any <PropertyGroup> blocks so adding one`);
        } else {
            console.log(`Found <PropertyGroup> block`);
            propertyGroupText = matches[0];
        }
        let versionFields = ["Version", "VersionPrefix", "AssemblyVersion"];
        var hasUpdateFields: any = false;
        var newPropertyGroupText = propertyGroupText;
        versionFields.forEach(element => {
            console.log(`Processing Field ${element}`);
            const csprojVersionRegex = `(<${element}>)(.*)(<\/${element}>)`;

            var regexp = new RegExp(csprojVersionRegex, "gmi");
            let matches;
            while ((matches = regexp.exec(newPropertyGroupText)) !== null) {
                var existingTag1: string = matches[0];
                console.log(`Existing Tag: ${existingTag1}`);
                var replacementTag1: string = `${matches[1]}${newVersion}${matches[3]}`;
                console.log(`Replacement Tag: ${replacementTag1}`);
                newPropertyGroupText = newPropertyGroupText.replace(existingTag1, replacementTag1);
                hasUpdateFields = true;
            }
        });
        if (hasUpdateFields === true) {
            var updateFileContents = content.replace(propertyGroupText, newPropertyGroupText);
            fs.writeFileSync(file, updateFileContents);
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
