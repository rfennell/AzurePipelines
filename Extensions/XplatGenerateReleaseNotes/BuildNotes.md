This extension now has a different structure to other extensions in this repo. This is because it has been decided to ship both the V1 and V2 versions of the task in parallel

- The V1 version of the task have hard coded versions in the task.json file
- The V2 version (as this is the code under active development) is set during the VSTS CI/CD process

To locally build the project run the the command

```
npm install
mpm run package
```

This creates the TS files in the _build folder

A package is created in the general form, note that the CI/CD process overloads a number of these command line to get the public/private gallery views and the extensionIDs

```
cd <to the root of this extension, i.e. the folder this file is in>
tfx extension create --json  --manifest-globs vss-extension.json --extension-id BM-VSTS-XplatGenerateReleaseNotes-DEV
```