The extension contains two tasks that can be used to update pages in Git based WIKIs

## Update a single WIKI Page

The WIKI Updater task allows the updating of a Git based WIKI using either an inputted string as the file contents data or a filename. This can be usefully paired with my [Generate Release Notes Extension](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-XplatGenerateReleaseNotes)

This can be used with both Azure DevOps and GitHub hosted WIKIs.

__Note:__ When working with Azure DevOps WIKIs, this task has the optional feature that it can update the WIKIs `.order` file. The `.order` file is used to [set the order of the Wiki pages ](https://docs.microsoft.com/en-us/azure/devops/project/wiki/wiki-file-structure?view=azure-devops#order-file) - See [#1009](https://github.com/rfennell/AzurePipelines/issues/1009) for more details.

## Update a WIKI with a set of pages defined by a wildcard

The WIKI Updater task that allows a set of files to be specified, using a wildcard, that will be committed to the Git repo. None that this task does not provided the option to rename the files as they are unloaded, or append to existing files.

This can be used with both Azure DevOps and GitHub hosted WIKIs

<hr>

__Note:__ If you see problems such as `Error: spawn git ENOENT` when using either of these tasks, please check the troubleshooting section at the end of this document before logging a support issue.

<hr>

### Usage of Both Tasks

Both tasks can be used in a build or a release

#### Required Parameters (for both tasks)
- Repo - The repo URL to update e.g in the form **https://dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki** (see the URL section below as to how to find this URL)
- Filename - The file (page to save/update), must end in .md else it will not appear on the WIKI e.g. page.md
- Message - The Git commit message
- GitName - The name for the .gitatrributes file e.g. _builduser_ (not a critical value)
- GitEmail - The email for the .gitatrributes file e.g. _builduser@domain_ (not a critical value)
- Tag Repo - If true a Git Tag set in the value of 'Tag' parameter in the repo. Defaults to false
- Tag - The tag to add to the repo, if the Tag repo flag is set to true
- Branch - The name of the **pre-existing** branch to checkout prior to committing the change, defaults to empty, so no checkout is done and writes are done to the default master branch
- Retries - The number of times to retry if a push fails. After a failed push a pull is run prior to the next attempt, default to 5

#### Required Parameters (Single File Task)
- DataIsFile - If true will upload a file, if false the upload is the content provided as a string
- Contents - If DataIsFile is false, this text to saved in the file set in the 'filename' parameter, so can be the output from another task passed as pipeline variable (there is a size limit of 32,760 characters for pipeline variables)
- SourceFile - If DataIsFile is true, this is the filename to upload, will be renamed to the value of the 'filename' parameter
- Replace File(s) - Replaces the page in the WIKI if set to True, if False will append or prepend to the page. Defaults to True
- Append to File(s) - Only meaningful if using the option to not replace the WIKI page. In this case, adds the contents to end of file if true, if false inserts at the new content start of the page. Defaults to True

#### Required Parameters (Multi File Task)
- TargetFolder - Any sub folder on the WIKI to place the files in
- SourceFolder - The folder to scan for files to upload
- Filter - The file filter used to scan the sourceFolder. Defaults to `**/*.md`

#### Advanced (for both tasks)
- LocalPath - The path used to clone the repo to for updating. Defaults to $(System.DefaultWorkingDirectory)\\repo
- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT". **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_ (see Authentication below)
- Username - The username to authenticate with the repo (see Authentication below)
- Password - The password or PAT to authenticate with the repo (see Authentication below) _Recommended that this is stored as secret variable_
- InjectExtraHeader -  If set to true, credentials are passed as a header value. If false, the default, they are passed in the URL. This option was added to address the issue [#613](https://github.com/rfennell/AzurePipelines/issues/613) which found that this means of authentication is required when working with an on-prem TFS/Azure DevOps Server
- Retries - The number of times to retry if a push fails. After a failed push a pull is run prior to the next attempt, default of 5

#### Advanced (Single File Task)
- fixLineFeeds - If set to true, `n are swapped to \\r\\n as this is required for most WIKIs. If false no replacement is made, this should be used for non-text based files e.g. images or PDFs. Only used when replacing the target file. Default is true
- TrimLeadingSpecialChar - See [#826](https://github.com/rfennell/AzurePipelines/issues/826), the appending or prepending files prior to uploading a leading special character gets added to the file. Setting this flag to true removes this first character. Default is false
- insertLinefeed - If set to true, when appending or prepending content to a page file a newline is inserted between the old and new content (See [#988](https://github.com/rfennell/AzurePipelines/issues/988)). Default is false
- updateOrderFile - See [#1009](https://github.com/rfennell/AzurePipelines/issues/1009) - If set to true, an new line for the uploaded file will be appending, or prepending, in the Azure DevOps WIKI .order file in the root of the repo. If the file does not exist it will be created. Default is false
- prependEntryToOrderFile - See [#1009](https://github.com/rfennell/AzurePipelines/issues/1009) -If `updateOrderFile` is set to true, this parameter will control whether the new entry is appended (when this is set to false) or prepending (when this is set to true). Default is false i.e append mode
- orderFilePath - See [#1302](https://github.com/rfennell/AzurePipelines/issues/1302) The path to the folder containing the .order file to update. If empty the .order file in the root of the WIKI will be used.


_For more authentication parameters see 'Authentication' section below_

## URL required to clone a WIKI repo

Prior to version 1.14.x the URL has to be edited into a special format i.e. trimmed of any content before the host name. With 1.14.x this is no longer required. There is now logic in the task to trim the url if needed.

So now both the old trimmed format url

`dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

or a full URL

`https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

are both acceptable forms for the `repo` parameter

### Azure DevOps Services & Azure DevOps Server (TFS) WIKIs

The URL to clone a Azure DevOps WIKIs is not obvious.

```
IT IS NOT THE URL SHOWN IN THE BROWSER WHEN YOU VIEW THE WIKI e.g:

https://dev.azure.com/richardfennell/Git%20project/_wiki/wikis/Git-project.wiki/1/Home

SO DON'T USE THIS FORM
```
To find the correct URL to clone the repo, and use it as the parameter for this task

1. Load the WIKI in a browser
1. At the top of the menu pane there is a menu (click the ellipsis ...)
1. Select the 'Clone repo' option
1. You will get a URL in the form https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki. This is the URL needed

### GitHub

Again, as with Azure DevOps, the URL to clone a GitHb WIKI also is not the one shown in the browser when the WIKI is viewed.

```
THIS IS NOT THE ONE YOU WANT

https://github.com/rfennell/AzurePipelines/wiki

SO DON'T USE IT
```

To find the correct URL

1. Load the WIKI in a browser
1. Look in lower right of any WIKI pages. It will be in the form https://github.com/rfennell/AzurePipelines.wiki.git. This is the full URL needed

## Authentication

There are two ways this task can authenticate, either putting the credentials in the URL in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

or the Header in the form

```
extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
```

In general, the former (default) should be used for Azure DevOps Services and GitHub, for latter for Azure DevOps Server/TFS (via the `InjectExtraHeader` set to true)

The following are supported means to authenticate with different services

### Authentication using OAUTH to Azure DevOps Services hosted Repos
The recommended approach is to use the build agents OAUTH Token for authentication. To do this

1. Allow the pipeline to access th OAUTH Token
   - For UI based pipelines this is [documented here](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands)
   - For YAML based pipelines the OAUTH token should automatically be available
1. Grant 'contribute' access on the target Azure DevOps WIKI Repo to user the build agent is scoped to run as
   - Control of the scope the build agent runs as is [documented here](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope).
   - Make sure that the 'Project Collection > Setting > Pipeline > Setting > Protect access to repositories in YAML pipelines' as not enabled. If set it can block access to the target repo.
   - Usually this is the '_Project Name_ Build Service' user (assuming this is the account the pipeline is running. The alternative if the wider scope is used is the 'Project Collection Build Service' user
1. Set the task's `UseAgentToken` parameter to true

Once this is set the `user` and the `password` parameters are managed by the task.

### Authentication using Personal Access Tokens to Azure DevOps Services hosted Repos
If you do not wish to use OAUTH then authentication can be done using Personal Access Tokens. To do this

1. Grant _contribute_ access on the target Azure DevOps WIKI to the user who's PAT is to be used
1. Generate PAT for the user with at least WIKI Read & Write access [see Azure Devops documentation](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page)

For this usecase for Azure DevOps Services then the `user` parameter is your organisation account name and the `password` is your PAT

### Authentication using OAUTH to On premises Azure DevOps Server & TFS hosted Repos
The recommended approach is to use for all on premises Azure DevOps Servers & TFS. To do this

1. Allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands)
1. Grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as).
1. Set the task's `UseAgentToken` parameter to true
1. Set the task's `InjectExtraHeader` parameter to true

Once this is set the `user` and the `password` parameters are managed by the task.

### Authentication using Personal Access Tokens to GitHub hosted Repos
The supported means to authenticate to a GitHub repo is using a Personal Access Token

1. For a user who has rights to update the WIKI, create [PAT](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)

Once this is create, for GitHub WIKIs, the `user` parameter is you Git account name and the `password` is your PAT

# Troubleshooting

The most common problems are usually cured by checking the following

- Make sure the repo URL parameter is in the correct format i.e. DOES NOT start with https://, anything before the domain name needs to be removed (see above).
- If you are using a private build agent and getting an error try swapping to a Microsoft hosted agent. Remember a build or release can make use of a mixture of agent phases.
- If intending to use the OAUTH build user credentials make sure that the agent phase is allowing access to the OAUTH Token (especially important for UI based build as this is not the default. Unlike in YAML where it is)
- If trying to use OAUTH and still having permission problems try swapping to a PAT for a user you know has rights to edit the WIKI.
- If using OAUTH make sure that the 'Project Collection > Setting > Pipeline > Setting > Limit job authorization scope to referenced Azure DevOps repositories' as not enabled. If set it can block access to the target repo.
- If there is any chance there is a proxy or corporate firewall between a private agent and the Azure DevOps instance enable the `Injectheader` option. This is most common when accessing Azure DevOps Server/TFS (see above).
- If you are on a private agent and get errors in the form `Error: spawn git ENOENT` when trying to clone a repo, make sure `C:\agent\externals\git\cmd` is in the environment path on agent machine [See this issue for details](https://github.com/rfennell/AzurePipelines/issues/738).

