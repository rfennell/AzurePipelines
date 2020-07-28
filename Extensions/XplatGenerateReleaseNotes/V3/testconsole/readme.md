# Local Test Harness
The testing cycle for Release Notes Templates can be slow, requiring a build and release cycle. To try to speed this process for users I have created a local test harness that allows the same calls to be made from a development machine as would be made within a build or release.

However, running this is not as simple was you might expect so please read the instruction before processing

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
The task takes many parameters, and reads runtime environment variable. These have to be passing into the local tester. Given the number, and the fact that most probably won't need to be altered, they are provided in settings JSON file. Samples are provided for a build and a release. For details on these parameters see the [task documentation](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task)

The only value not stored in the JSON files are the PATs required to access the REST API. This reduces the chance of them being copied onto source control by mistake.

- [Azure DevOps PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page) (Required) - within a build or release is this is automatically picked up. For this tool it must be provided
- [GitHub PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) - this is an optional parameter for the task, you only need to provide it if working with private GitHub repos.
- Bitbucket User Name - this is an optional parameter for the task, you only need to provide it if working with private Bitbucket repos. It must be paired with a App Secret. It will be name of th user the App Secret was created for.
- [Bitbucket App Secret](https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/?_ga=2.216122326.1721502558.1595774436-1359824809.1581077155) - this is an optional parameter for the task, you only need to provide it if working with private Bitbucket repos. It must be paired with a User Name

### Test a Build
To run the tool against a build

1. In the settings file make sure the TeamFoundationCollectionUri, TeamProject and BuildID are set to the build you wish to run against, and that the ReleaseID is empty.
1. Run the command
   `node GenerateReleaseNotesConsoleTester.js --filename settings.json --pat <Azure-DevOps-PAT> --githubpat <Optional GitHub-PAT> --bitbucketuser <Optional Bitbucket User> --bitbucketsecret <Optional Bitbucket App Secret>`
1. Assuming you are using the sample settings you should get an output.md file with your release notes.

### Test a Release
To run the tool against a release is but more complex. This is because the logic looks back to see the most recent successful run. So if you release ran to completion you will get no notes as there has been no change.

You have two options
- Allow a build a trigger, but cancel it. You can then use its ReleaseID to compare with the last release
- Add a stage to your release this is skipped, only run on a manual request and use this as the comparison stage to look for difference

To run the tool...
1. In the settings file make sure the TeamFoundationCollectionUri, TeamProject, BuildID, EnvironmentName (as stage in your process), ReleaseID and releaseDefinitionId are set for the release you wish to run against.
1. Run the command
   `node .\GenerateReleaseNotesConsoleTester.js release-settings.json <your-Azure-DevOps-PAT> < your GitHub PAT>`
1. Assuming you are using the sample settings you should get an output.md file with your release notes.
