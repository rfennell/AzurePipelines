import * as fs from "fs";
import * as path from "path";
import tl = require("vsts-task-lib/task");

function DumpField(field) {
    var line = `- **Argument:** ${field.name}\r\n`;
    line += `    - **Description:** ${field.helpMarkDown}\r\n`;
    line += `    - **Type:** ${field.type} \r\n`;
    if (field.type === "picklist") {
       field.options.psobject.Members.forEach(option => {
            if (option === "noteproperty") {
                line += `        - ${option} \r\n`;
            }
       });
    }
    line += `    - **Required:** ${field.required}\r\n`;
    line += `    - **Default (if defined):** ${field.defaultValue}\r\n`;
    return line;
}

// List all task.json file in a synchronous fashion
function listFiles(dir, filelist) {
    var files = fs.readdirSync(dir);
    filelist = filelist || [];
    files.forEach(function(file) {
        if (fs.statSync(path.join(dir, file)).isDirectory()) {
            filelist = listFiles(path.join(dir, file), filelist);
        }
        else {
            if (file === "task.json") {
                filelist.push(path.join(dir, file));
            }
        }
    });
    return filelist;
}

function GetTask(filePath) {
    const task = JSON.parse(fs.readFileSync(filePath, "utf8"));
    logInfo(`Adding YAML sample for task ${task.name}`);
    var markdown = `## ${task.name} \r\n`;
    markdown += `${task.description} \r\n`;
    markdown += `### YAML snippet \r\n`;
    markdown += `\`\`\`\`\`\`\r\n`;
    markdown += `# ${task.friendlyName}\r\n`;
    markdown += `# Description - ${task.description}\r\n`;
    markdown += `- task: ${task.name}\r\n`;
    markdown += `  inputs: \r\n`;
    markdown += `     # Required arguments\r\n`;

    task.inputs.forEach(field => {
        if (field.required === true) {
            markdown += `     ${field.name}: ${field.defaultValue}\r\n`;
        }
    });

    markdown += `\`\`\`\`\`\`\r\n`;
    markdown += `### Arguments \r\n`;

    logInfo ("   Default arguments");
    task.inputs.forEach(field => {
        if (field.groupName === undefined) {
            markdown += DumpField (field);
        }
    });

    task.groups.forEach(group => {
        logInfo (`   Argument Group ${group.displayName}`);
        markdown += `"#### ${group.displayName}  \r\n`;
        task.inputs.forEach(field => {
            if (field.groupName === group.name) {
                markdown += DumpField (field);
            }
        });
    });
    return markdown;
}

function writeToFile (fileName, data) {
    fs.appendFileSync (fileName, data);
}

function mkDirByPathSync(targetDir, { isRelativeToScript = false } = {}) {
    const sep = path.sep;
    const initDir = path.isAbsolute(targetDir) ? sep : "";
    const baseDir = isRelativeToScript ? __dirname : ".";

    return targetDir.split(sep).reduce((parentDir, childDir) => {
      const curDir = path.resolve(baseDir, parentDir, childDir);
      try {
        if (fs.existsSync(curDir) === false) {
            fs.mkdirSync(curDir);
        }
      } catch (err) {
        if (err.code === "EEXIST") { // curDir already exists!
          return curDir;
        }
        if (err.code === "EPERM") { // curDir is Windows drive root
           return curDir;
        }
        // To avoid `EISDIR` error on Mac and `EACCES`-->`ENOENT` and `EPERM` on Windows.
        if (err.code === "ENOENT") { // Throw the original parentDir error on curDir `ENOENT` failure.
          throw new Error(`EACCES: permission denied, mkdir '${parentDir}'`);
        }
        const caughtErr = ["EACCES", "EPERM", "EISDIR"].indexOf(err.code) > -1;
        if (!caughtErr || caughtErr && curDir === path.resolve(targetDir)) {
          throw err; // Throw if it's just the last created dir.
        }
      }

      return curDir;
    }, initDir);
  }

function filePath(outDir, extension) {
    return path.join(outDir, `${extension}-YAML.md`);
}

async function main(inDir, outDir, filePrefix) {

    // Make sure the folder exists
    mkDirByPathSync(outDir);

    // Get the extension details
    const extension = JSON.parse(fs.readFileSync(path.join(inDir, "vss-extension.json"), "utf8"));

    // Delete the target file
    if (filePrefix === "") {
        filePrefix = extension.id;
    }

    const fileName = filePath(outDir, extension.id);
    if (fs.existsSync(fileName)) {
        logInfo(`Deleting old output file '${fileName}`);
        fs.unlinkSync(fileName);
    }

    // Write the header
    logInfo(`Creating output file '${fileName} for extension '${extension.name}'`);
    writeToFile(fileName, `# ${extension.name} \r\n`);
    writeToFile(fileName, `The '${extension.name}' package contains the following tasks. The table show the possible variables that can be used in YAML Azure DevOps Pipeline configurations \r\n`);

    logInfo(`Scanning for task.json files under '${inDir}`);
    // Note we look for tasks so we see extensions multiple time
    var list = listFiles(inDir, list);
    list.forEach(task => {
        writeToFile(fileName, GetTask(task));
    });
}

function logInfo(msg) {
    console.log(msg);
}

var outDir = tl.getInput("outDir");
var inDir = tl.getInput("inDir");
var filePrefix = tl.getInput("filePrefix");

logInfo(`Variable: outDir [${outDir}]`);
logInfo(`Variable: inDir [${outDir}]`);
logInfo(`Variable: inDir [${filePrefix}]`);

main(inDir, outDir, filePrefix);
