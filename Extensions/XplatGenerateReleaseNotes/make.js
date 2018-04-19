// parse command line options
var minimist = require('minimist');
var mopts = {
    string: []
};
var options = minimist(process.argv, mopts);

// remove well-known parameters from argv before loading make,
// otherwise each arg will be interpreted as a make target
process.argv = options._;

var make = require('shelljs/make');
var path = require('path');
var util = require('./make-util');
var semver = require('semver');

// util functions
var matchFind = util.matchFind;
var banner = util.banner;
var ensureExists = util.ensureExists;
var test = util.test;
var validateTask = util.validateTask;
var mkdir = util.mkdir;
var fail = util.fail;
var run = util.run;
var cp = util.cp;

// global paths
var buildPath = path.join(__dirname, '_build');

// node min version
var minNodeVer = '6.10.3';
if (semver.lt(process.versions.node, minNodeVer)) {
    fail('requires node >= ' + minNodeVer + '.  installed: ' + process.versions.node);
}

// Resolve list of versions
var versionList;
versionList = matchFind("V*", __dirname, { noRecurse: true, matchBase:true })
    .map(function(item) {
        return path.basename(item);
    });

if (!versionList.length){
    fail('Unable to find task versions matching pattern [V*]');
}

target.clean = function () {
    banner(`Deleting global dist folder [${buildPath}]`);
    rm('-Rf', buildPath);
    mkdir('-p', buildPath);

    versionList.forEach(function (version){
        banner(`Cleaning local task folders [${version}]...`)

        var versionPath = path.join(__dirname, version);
        ensureExists(versionPath)
        
        console.log('Deleting node_modules')
        rm('-rf',path.join(versionPath, "node_modules"));

        console.log('Deleting js files')
        rm('-f', path.join(versionPath, "*.js"));
        rm('-f', path.join(versionPath, "*.js.map"));
    });
};

target.install = function(){

    versionList.forEach(function (version){
        banner(`Installing [${version}]`);

        var versionPath = path.join(__dirname, version);
        ensureExists(versionPath)

        // npm install folder
        try{
            util.run(`npm i`,  { env: process.env, cwd: versionPath, stdio: 'inherit' })
        }catch(error){
            fail(error);
        }
    });
};

target.build = function() {
    versionList.forEach(function (version){
        banner(`Building [${version}]`);

        var versionPath = path.join(__dirname, version);
        ensureExists(versionPath)

        // load the task.json
        var outDir;
        var taskJsonPath = path.join(versionPath, 'task.json');
        if (test('-f', taskJsonPath)) {
            var taskDef = require(taskJsonPath);
            validateTask(taskDef);
        } else {
            fail(`Failed to locate task.json in [${taskJsonPath}]`);
        }
        
        // Determine OS and set command accordingly
        const cmd = /^win/.test(process.platform) ? 'npm.cmd' : 'npm';

        // lint
        if (test('-f', path.join(versionPath, "tslint.json"))){
            try{
                console.log(`Starting lint`);
                util.run(`npx tslint -c tslint.json *.ts test/*.ts`,  { env: process.env, cwd: versionPath, stdio: 'inherit' })
            }catch(error){
                fail(error);
            }
        }else{
            console.log(`Skipping lint because tsling.json does not exist.`)
        }

        // Compile
        if (test('-f', path.join(versionPath, "tsconfig.json"))){
            try{
                console.log(`Starting Compile`);
                util.run(`npx tsc -p ./`,  { env: process.env, cwd: versionPath, stdio: 'inherit' })
            }catch(error){
                fail(error);
            }
        }else{
            console.log(`Skipping lint because tsconfig.json does not exist.`)
        }        
    });
};

target.package = function(){
    target.clean();
    target.install();
    target.build();

    var outDir = path.join(buildPath, 'dist');

    versionList.forEach(function (version){
        banner(`Packaging [${version}]`);

        var versionPath = path.join(__dirname, version);
        ensureExists(versionPath)

        var versionOutDir = path.join(outDir, version);

        mkdir('-p', versionOutDir);

        // npm prune
        console.log('Running npm prune')
        try{
            util.run(`npm prune --production`,  { env: process.env, cwd: versionPath, stdio: 'inherit' })
        }catch(error){
            fail(error);
        }

        // copy files
        console.log('Copying node modules')
        cp('-r', path.join(versionPath, "node_modules"), versionOutDir);

        console.log('Copying js files')
        cp(path.join(versionPath, "*.js"), versionOutDir);
        
        console.log('Copying misc files')
        cp(path.join(versionPath, "task.json"), versionOutDir);
        cp(path.join(versionPath, "icon.png "), versionOutDir);
    });

    // not needed as these files are pulled from their default locations, assumig tfx is run from this folder. Only the .TS files are in the _build folders
    // console.log('Copying manifest files')
    // cp('vss-extension.json', outDir);
    // cp('readme.md', outDir);
    // cp('license.md', outDir);
    // cp('icon.png', outDir);
    // cp('-r','images', outDir);
};