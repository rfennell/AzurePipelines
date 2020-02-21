This set of tasks perform WIKI management operations

## Update a WIKI Page

The WIKI Updater task allows the updating of a Git based WIKI using an inputted string as the file data. This can be usefully paired with my [Generate Release Notes Extension](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-XplatGenerateReleaseNotes)

This can be used with both Azure DevOps and GitHub hosted WIKIs

### Usage

Add the task to a build or release

#### Required Parameters
- Repo - The repo URL to update e.g in the form **dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki** (see the URL section below)
- Filename - The file (page to save/update), must end in .md else it will not appear on the WIKI e.g. page.md
- DataIsFile - If true will upload a file, if false the upload is the content provided
- Contents - If DataIsFile is false, this text to save in the file, can be the output from another task passed as pipeline variable
- SourceFile - If DataIsFile is true, this is the filename to upload, will be renamed to the value of the 'filename' parameter"
- Message - The Git commit message
- GitName - The name for the .gitatrributes file e.g. _builduser_
- GitEmail - The email for the .gitatrributes file e.g. _builduser@domain_
- Replace File - Replace the file in the WIKI defaults to True
- Append to File - Only meaninfful if using the option to not replace the file. In this case, adds the contents to end of file if true, if false inserts at the start of the page defaults to True
- Tag Repo - If true the tag set in the Tag parameter will be written to the repo
- Tag - The tag to add to the repo

#### Advanced

- LocalPath - The path used to clone the repo to for updating. Defaults to $(System.DefaultWorkingDirectory)\\repo
- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT". **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_
- Username - The username to authenticate with the repo (see below)
- Password - The password or PAT to authenticate with the repo (see below) _Recommended that this is stored as secret variable_
- InjectExtraHeader - To address [#613](https://github.com/rfennell/AzurePipelines/issues/6130) injects extraHeader value into all clone operations",


For more authentication parameters see 'Authentication' section below

### URL required to clone a WIKI repo

#### Azure DevOps WIKIs

The URL to clone a Azure DevOps WIKIs is not obvious. 

```
IT IS NOT THE URL SHOWN IN THE BROWSER WHEN YOU VIEW THE WIKI e.g: 

https://dev.azure.com/richardfennell/Git%20project/_wiki/wikis/Git-project.wiki/1/Home

SO DON'T USE THIS FORM
```
To find the correct URL to clone the repo

1. Load the WIKI in a browser
2. At the top of the menu pane there is a menu (click the ellipsis ...)
3. Select the 'Clone repo' option
4. You will get a URL in the form https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki. This is the URL needed. The part you need to add as the repo parameter for this task is everything after the @

#### GitHub

The URL to clone a GitHb WIKI also is not the one shown in the browser when the WIKI is viewed.

```
THIS IS NOT THE ONE YOU WANT

https://github.com/rfennell/AzurePipelines/wiki

SO DON'T USE IT
```

However, it is more obvious to find the correct URL, it is shown in lower right of all WIKI pages. It will be in the form

```
https://github.com/rfennell/AzurePipelines.wiki.git
```

### Authentication

The URL used for authenticated connection to a repo is in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

#### Automated authentication OAUTH to Azure DevOps hosted Repos
If using the OAUTH token then the **${user}** and the **${password}** are managed by the task. 

#### Manual Management of Authentication
However they can be manually managed.

##### GitHub

For GitHub then the **${user}** is you Git account name and the **${password}** is your [PAT](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)

##### Azure DevOps

For Azure DevOps then the **${user}** is you organisation account name and the **${password}** is your [PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts)



