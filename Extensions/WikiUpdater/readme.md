A task to update a page in Git based WIKI

## Update a WIKI Page

The WIKI Updater task allows the updating of a Git based WIKI using an inputted string as the file data. This can be usefully paired with my [Generate Release Notes Extension](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-XplatGenerateReleaseNotes)

This can be used with both Azure DevOps and GitHub hosted WIKIs

### Usage

Add the task to a build or release

#### Required Parameters
- Repo - The repo URL to update e.g in the form **dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki** (see the URL section below as to how to find this URL)
- Filename - The file (page to save/update), must end in .md else it will not appear on the WIKI e.g. page.md
- DataIsFile - If true will upload a file, if false the upload is the content provided as a string
- Contents - If DataIsFile is false, this text to saved in the file set in the 'filename' parameter, can be the output from another task passed as pipeline variable
- SourceFile - If DataIsFile is true, this is the filename to upload, will be renamed to the value of the 'filename' parameter
- Message - The Git commit message
- GitName - The name for the .gitatrributes file e.g. _builduser_ (not a critical value)
- GitEmail - The email for the .gitatrributes file e.g. _builduser@domain_ (not a critical value)
- Replace File - Replaces the page in the WIKI if set to True, if False will append or prepend to the page. Defaults to True
- Append to File - Only meaningful if using the option to not replace the WIKI page. In this case, adds the contents to end of file if true, if false inserts at the new content start of the page. Defaults to True
- Tag Repo - If true a Git Tag set in the value of 'Tag' parameter in the repo. Defaults to false
- Tag - The tag to add to the repo, if the Tage repo flag is set to true

#### Advanced

- LocalPath - The path used to clone the repo to for updating. Defaults to $(System.DefaultWorkingDirectory)\\repo
- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT". **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_ (see Authentication below)
- Username - The username to authenticate with the repo (see Authentication below)
- Password - The password or PAT to authenticate with the repo (see Authentication below) _Recommended that this is stored as secret variable_
- InjectExtraHeader -  If set to true, credentials are passed as a header value. If false, the default, they are passed in the URL. This option was added to address the issue [#613](https://github.com/rfennell/AzurePipelines/issues/613) which found that this means of authentication is required when working with an on-prem TFS/Azure DevOps Server


_For more authentication parameters see 'Authentication' section below_

### URL required to clone a WIKI repo

#### Azure DevOps Services & Azure DevOps Server (TFS) WIKIs

The URL to clone a Azure DevOps WIKIs is not obvious. 

```
IT IS NOT THE URL SHOWN IN THE BROWSER WHEN YOU VIEW THE WIKI e.g: 

https://dev.azure.com/richardfennell/Git%20project/_wiki/wikis/Git-project.wiki/1/Home

SO DON'T USE THIS FORM
```
To find the correct URL to clone the repo, and use as the parameter for this task

1. Load the WIKI in a browser
1. At the top of the menu pane there is a menu (click the ellipsis ...)
1. Select the 'Clone repo' option
1. You will get a URL in the form https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki. This is the full URL needed, but you only require part of it for this task. 
1. The part you need to add as the repo parameter for this task is everything after the @ i.e dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki

#### GitHub

Again, as with Azure DevOps, the URL to clone a GitHb WIKI also is not the one shown in the browser when the WIKI is viewed.

```
THIS IS NOT THE ONE YOU WANT

https://github.com/rfennell/AzurePipelines/wiki

SO DON'T USE IT
```

To find the correct URL

1. Load the WIKI in a browser
1. Look in lower right of any WIKI pages. It will be in the form https://github.com/rfennell/AzurePipelines.wiki.git. This is the full URL needed, but you only require part of it for this task. 
1. The part you need to add as the repo parameter for this task is everything after the // i.e github.com/rfennell/AzurePipelines.wiki.git

### Authentication

There are two ways this task can authenticate, either using the URL where the credentials are passed as part of the URL in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

or the Header in the form

```
extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
```

The former should be used for Azure DevOps Services and GitHub, for latter for Azure DevOps Server/TFS

The following are supported means to authenticate with different services

#### Authentication using OAUTH to Azure DevOps Services hosted Repos
The recommended approach is to use the build agents OAUTH Token for authentication. To do this

1. Allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) 
1. Grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). 
1. Set the task's `UseAgentToken` parameter to true

Once this is set the `user` and the `password` parameters are managed by the task. 

#### Authentication using Personal Access Tokens to Azure DevOps Services hosted Repos
If you do not wish to use OAUTH then authentication can be done using Personal Access Tokens. To do this

1. Grant _contribute_ access on the target Azure DevOps WIKI to the user who's PAT is to be used
1. Generate PAT for the user with at least WIKI Read & Write access [see Azure Devops documentation](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page)

For this usecase for Azure DevOps Services then the `user` parameter is your organisation account name and the `password` is your PAT

#### Authentication using OAUTH to On premises Azure DevOps Server & TFS hosted Repos
The recommended approach is to use for all on premises Azure DevOps Servers & TFS. To do this

1. Allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) 
1. Grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). 
1. Set the task's `UseAgentToken` parameter to true
1. Set the task's `InjectExtraHeader` parameter to true

Once this is set the `user` and the `password` parameters are managed by the task. 

#### Authentication using Personal Access Tokens to GitHub hosted Repos
The supported means to authenticate to a GitHub repo is using a Personal Access Token

1. For a user who has rights to update the WIKI, create [PAT](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)

Once this is create, for GitHub WIKIs, the `user` parmeter is you Git account name and the `password` is your PAT




