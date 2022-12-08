# Local Test Harness
The testing cycle for Release Notes Templates can be slow, requiring a build and/or release cycle. To try to speed this process for users I have created a local test harness that allows the same calls to be made from a development machine as would be made within a build or release. To in effect re-run the release notes generation (either making new API calls or using a local payload file) for a previous build or release from the command line as many times as you wish.

However, running this tool is not as simple was you might expect so **please read the instructions** before proceeding.

## Setup and Build
1. Clone the repo contain this code.
1. Change to the folder

   `<repo root>Extensions\XplatGenerateReleaseNotes\V3\testconsole`
1. Build the tool using NPM (this does assume [Node](https://nodejs.org/en/download/_) is already installed)
   ```
   npm install
   npm run build
   ```

## Running the Tool

### Task Parameters
The task takes many parameters and reads runtime environment variables. These all have to be passing into the local tester.

Given the number, and the fact that most probably won't need to be altered, they are all provided in a settings JSON file as opposed to command line parameters. Samples JSON files are provided for a [build](build-settings.json) (for Classic Build and all YAML Pipelines) and a [release](release-settings.json) (Classic Release).

**Note:** You will have to update the settings JSON file you are using with values appropriate to your Azure DevOps organisation.

The values in the JSON file related to two categories
- Environment variables set by Azure DevOps. These should be obtained from the build/release log of the run you are going to repeat. You might need to run the build/release with the variable `syste,debug=true` to see the detailed logging.
- Task parameters you would set in the build/release pipeline. For details on all the parameters avaliable in the JSON file see the project WIKI [task documentation](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task)

### Command Line Parameters

- **Filename** (Required) - the name of the settings file discussed previously
- **Access Tokens**

  The PATs required to access the REST API are not stored in the JSON file. This reduces the chance of them being copied onto source control by mistake.

  - [Azure DevOps PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page) (Required) - within a build or release is this is automatically picked up. For this tool it must be provided
  - [GitHub PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) - this is an optional parameter for the task, you only need to provide it if working with private GitHub repos.
  - [Bitbucket User Name](https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/?_ga=2.216122326.1721502558.1595774436-1359824809.1581077155) - this is an optional parameter for the task, you only need to provide it if working with private Bitbucket repos. It must be paired with a App Secret. It will be name of the user the App Secret was created for.
  - [Bitbucket App Secret](https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/?_ga=2.216122326.1721502558.1595774436-1359824809.1581077155) - this is an optional parameter for the task, you only need to provide it if working with private Bitbucket repos. It must be paired with a User Name

- **payloadfile** - allows a previous exported JSON payload file to replayed through this tool, thus bypassing the need to make all the Azure DevOps API calls. This can greatly speed up the dev/test cycle for a template

### Testing a Classic Build or YAML Pipeline
To run the tool against a Classic Build or YAML Pipeline

1. In the [settings file](build-settings.json) make sure the `TeamFoundationCollectionUri`, `TeamProject` and `BuildID` are set to the build you wish to run against, and that the `ReleaseID` is empty.
1. Run the command

   `node GenerateReleaseNotesConsoleTester.js --filename build-settings.json --pat <Azure-DevOps-PAT> --githubpat <Optional GitHub-PAT> --bitbucketuser <Optional Bitbucket User> --bitbucketsecret <Optional Bitbucket App Secret> --payloadfile <Option JSON file>`
1. Assuming you are using the sample settings you should get an `output.md` file with your release notes.

### Test a Classic Release
To run the tool against a Classic Release is bit more complex. This is because the logic looks back to see the most recent successful run. So if you release ran to completion you will get no release notes as there has been no changes.

You have two options:
- Allow a release a trigger, but cancel it. You can then use its `ReleaseID` to compare with the last release
- Add a stage to your release this is skipped, only run on a manual request and use this as the comparison stage to look for difference

To run the tool...
1. In the [settings file](release-settings.json) make sure the `TeamFoundationCollectionUri`, `TeamProject`, `overrideStageName` (a stage in your process), `ReleaseID` and `releaseDefinitionId` are set for the release you wish to run against.
1. Run the command

   `node .\GenerateReleaseNotesConsoleTester.js release-settings.json <your-Azure-DevOps-PAT> < your GitHub PAT>`
1. Assuming you are using the sample settings you should get an `output.md` file with your release notes.


## Debugging
### Payload Logging
All the logging for the task will be shown to the console. So you can see the path that was taken through the code to generate the release notes.

However, it can be useful to get the raw JSON data passed into the handlebars template. This allows you to work out the handlebar tags required.

To dump this JSON data, set the following values in the configuration file

```
"dumpPayloadToFile": "true",
"dumpPayloadFileName": "payload.json",
```

### Visual Studio Code
You can debug the task using Visual Studio Code. To do this have a `launch.json` file with the following configuration

```
{
    "version": "0.2.0",
    "configurations":
    [
        {
            "name": "Generate Release Notes Console Tester",
            "program": "${workspaceFolder}/Extensions/XplatGenerateReleaseNotes/v3/testconsole/GenerateReleaseNotesConsoleTester.js",
            "request": "launch",
            "cwd": "${workspaceRoot}/Extensions/XplatGenerateReleaseNotes/v3/testconsole",
            "type": "node",
            "args": [
                "--filename", "build-settings.json",
                "--pat", "<pat>",
                "--githubpat", "<pat>",
                "--bitbucketuser", "<user>",
                "--bitbucketsecret", "<secret>",
                "--payloadFile", "<file>]
        }
    ]
}
```

Replace the `<pat>` tags with values suitable for your instance.