The extension contains a task that wrapper the Max Melcher's [AzureDevOps.WikiPDFExport command line tool](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport);

The task allows you to 
1. Optionally clone a WIKI repo that is hosted on Azure DevOps or GitHub into a local folder
1. Export 
   - the whole WIKI as a PDF (assuming a .order file is present)
   - a single named file

Note: If used without the clone step, it can allow the export to PDF of any markdown file in the file system.

<hr>

__Note:__ If you see problems such as `Error: spawn git ENOENT` when cloing a repo using this tasks, please check the troubleshooting section at the end of this document before logging a support issue.

<hr>

## Usage

### Parameters
#### General
- CloneRepo - a flag whether to cloen the repo or not
- Repo - The repo URL to update e.g in the form **https://dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki** (see the URL section below as to how to find this URL)
- LocalPath - The Path to clone the repo into, or the folder structure containing the file(s) to export
- SingleFile - Optional single file to export in the localPath folder e.g. page.md
- ExtraParameters - Optional any extra [WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/) you wish to pass to the command line tool
#### Git Clone Specific
- Branch - The name of the **pre-existing** branch to checkout prior to the export, defaults to the default branch
- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT". **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_ (see Authentication below)
- Username - The username to authenticate with the repo (see Authentication below)
- Password - The password or PAT to authenticate with the repo (see Authentication below) _Recommended that this is stored as secret variable_
- InjectExtraHeader -  If set to true, credentials are passed as a header value. If false, the default, they are passed in the URL. This option was added to address the issue [#613](https://github.com/rfennell/AzurePipelines/issues/613) which found that this means of authentication is required when working with an on-prem TFS/Azure DevOps Server

_For more authentication parameters see 'Authentication' section below_

### URL required to clone a WIKI repo

Urls in the form

`dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

or a full URL 

`https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

are both acceptable forms for the `repo` parameter

#### Azure DevOps Services & Azure DevOps Server (TFS) WIKIs

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

#### GitHub

Again, as with Azure DevOps, the URL to clone a GitHb WIKI also is not the one shown in the browser when the WIKI is viewed.

```
THIS IS NOT THE ONE YOU WANT

https://github.com/rfennell/AzurePipelines/wiki

SO DON'T USE IT
```

To find the correct URL

1. Load the WIKI in a browser
1. Look in lower right of any WIKI pages. It will be in the form https://github.com/rfennell/AzurePipelines.wiki.git. This is the full URL needed

### Authentication

There are two ways this task can authenticate, either putting the credentials in the URL in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

or the Header in the form

```
extraHeaders = [`-c http.extraheader=AUTHORIZATION: bearer ${password}`];
```

In general, the former should be used for Azure DevOps Services and GitHub, for latter for Azure DevOps Server/TFS

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

Once this is create, for GitHub WIKIs, the `user` parameter is you Git account name and the `password` is your PAT

# Troubleshooting

The most common problems are usually cured by checking the following

- Make sure the repo URL parameter is in the correct format i.e. DOES NOT start with https://, anything before the domain name needs to be removed (see above).
- If you are using a private build agent and getting an error try swapping to a Microsoft hosted agent. Remember a build or release can make use of a mixture of agent phases.
- If intending to use the OAUTH build user credentials make sure that the agent phase is allowing access to the OAUTH Token (especially important for UI based build as this is not the default. Unlike in YAML where it is)
- If trying to use OAUTH and still having permission problems try swapping to a PAT for a user you know has rights to edit the WIKI.
- If there is any chance there is a proxy or corporate firewall between a private agent and the Azure DevOps instance enable the `Injectheader` option. This is most common when accessing Azure DevOps Server/TFS (see above).
- If you are on a private agent and get errors in the form `Error: spawn git ENOENT` when trying to clone a repo, make sure `C:\agent\externals\git\cmd` is in the environment path on agent machine [See this issue for details](https://github.com/rfennell/AzurePipelines/issues/738).

