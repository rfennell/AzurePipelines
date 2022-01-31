# Overview
## What it does
The extension contains a task that wrappers Max Melcher's [AzureDevOps.WikiPDFExport command line tool](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport) that can be used to covert a WIKI to a PDF file.

When run, the task will download the current release (or optionally a pre-release version) of the AzureDevOps.WikiPDFExport command line tool from GitHub. It then allows you to
1. Either
   - Optionally clone a Git based WIKI repo that is hosted on Azure DevOps or GitHub into a local folder for exporting
   - Or if you already have the folder structure on the agent then this feature can be skipped
2. The task will then export either
   - the whole WIKI structure as a PDF (based on the .order file is present in the root)
   - a single named file

## How the AzureDevOps.WikiPDFExport tool is obtained
There is a maximum size limit for Azure DevOps extension VSIX packages. Due to this limitation and the size of the AzureDevOps.WikiPDFExport tool, we cannot ship the executable within the VSIX. This problem is addressed in two ways

- **[Default]** The task downloads the latest (or pre-release) version of the tool from releases in [AzureDevOps.WikiPDFExport command line tool's GitHub Repo](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases) <br>**Note:** This method does require that agent can communicate with the following Internet endpoints: __github.com__,__objects.githubusercontent.com__ and __storage.googleapis.com__ to download the latest version of the tool from GitHub. This is potentially an issue for self hosted agents behind corporate firewalls.
- If you require a specific version of the tool, or cannot use the automatic download, you can load the tool from a fixed location known to the agent e.g. have it already on the agent, or downloaded as a [pipeline resource](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/resources?view=azure-devops&tabs=schema) such as a __repository__, or __package__. Or, you could also download the tool using your own script as shown in [the discussion #1170](https://github.com/rfennell/AzurePipelines/issues/1170#issuecomment-995698253) on this tasks GitHub repo, thus bypassing the need for this task as all the work is done on the script.

## Versions of this task
There have been two major versions of this task
### V1.x.x
The initial Windows only version of the task that written to wrapper [version 3.3.0 of AzureDevOps.WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases/tag/v3.3.0).

With the release of [version 4.0.0 of AzureDevOps.WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases/tag/4.0.0) this version of this task may fail (as the task can only download the latest version of the tool, the library used to do this does not have the ability to download a specific version). This is because [version 4.0.0 of AzureDevOps.WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases/tag/4.0.0) requires .NET6 to be present on the agent.

So if you still wish to use the V1 version of this task, you must either

- Download the older [version 3.3.0 of AzureDevOps.WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases/tag/v3.3.0) and pass it's path into this task using the `overrideExePath` parameter.
- Allow the task to get the .NET6 based version of the tool but install .NET6 on the agent prior to running this task (see below)

### V2.x.x
This version provides cost platform support using the new .NET6 based [version 4.0.0 of AzureDevOps.WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/releases/tag/4.0.3), and hence supports Windows, Linux and Mac usage.

# Usage
## .NET 6
The AzureDevOps.WikiPDFExport tool since 4.0.x is .NET 6 based. Hence [.NET 6](https://dotnet.microsoft.com/download/dotnet/6.0) must be installed on the agent.

In many cases this runtime will be present on a build agent e.g if VS2022 is installed. If it is not present it can be installed as a step in a build pipeline using the [usedotnet task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/tool/dotnet-core-tool-installer?view=azure-devops) before this task is called.

> Note: this technique will work for both V1 and V2 of this task

```
steps:
- task: UseDotNet@2
  displayName: 'Use .NET Core runtime'
  inputs:
    packageType: 'runtime'
    version: '6.0.x'
    includePreviewVersions: false
- task: richardfennellBM.BM-VSTS-WikiPDFExport-Tasks.WikiPDFExportTask.WikiPdfExportTask@2
  displayName: 'Export Single File'
  inputs:
    cloneRepo: false
    usePreRelease: false
    localpath: '$(System.DefaultWorkingDirectory)'
    singleFile: 'infile.md'
    outputFile: '$(Build.ArtifactStagingDirectory)/singleFile.pdf'
    ...
```

## Parameters
### AzureDevOps.WikiPDFExport Specific
- SingleFile - Optional single file to export in the localPath folder e.g. page.md
- RootExportPath - The path to the root of the cloned the repo if exporting the whole repo, a folder within the repo to export part of the repo or finally the folder containing a single file to export. For this final option the filename must be specified below
- ExtraParameters - Any optional extra as defined at [WikiPDFExport](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport/) you wish to pass to the command line tool - noting that this task automatically manages the -p, -s, -c and -v parameters
- usePreRelease - If set to true pre-release version of the [AzureDevOps.WikiPDFExport tool](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport) tool will be used
- overrideExePath - An optional path to a previously download copy of the [AzureDevOps.WikiPDFExport tool](https://github.com/MaxMelcher/AzureDevOps.WikiPDFExport). If not set the task will download the current release of this tool
- downloadPath - The path the tool will be downloaded to, default to the Azure DevOps pre-defined variable `Agent.TempDirectory`
#### Git Clone Specific
- CloneRepo - a boolean flag whether to clone the repo or not
- Repo - The repo URL to update e.g in the form **https://dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki** (see the URL section below as to how to find this URL)
- LocalPath - The path to clone the repo into
- Branch - The name of the **pre-existing** branch to checkout prior to the export. If not set the default branch is used.
- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT. **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access on the target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_ (see Authentication below)
- Username - The username to authenticate with the repo (see Authentication below)
- Password - The password or PAT to authenticate with the repo (see Authentication below) _Recommended that this is stored as secret variable_
- InjectExtraHeader -  If set to true, credentials are passed as a header value. If false, the default, they are passed in the URL. This option was added to address the issue [#613](https://github.com/rfennell/AzurePipelines/issues/613) which found that this means of authentication is required when working with an on-prem TFS/Azure DevOps Server

> _For more authentication parameters see 'Authentication' section below_

## URL required to clone a WIKI repo

Prior to version 1.14.x the URL has to be edited into a special format i.e. trimmed of any content before the host name. With 1.14.x this is no longer required. There is now logic in the task to trim the url if needed.

So now both the old trimmed format url

`dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

or a full URL

`https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki`

are both acceptable forms for the `repo` parameter

### Azure DevOps Services & Azure DevOps Server (TFS) WIKIs

The URL to clone a Azure DevOps WIKIs is not obvious.

> **IT IS NOT THE URL SHOWN IN THE BROWSER WHEN YOU VIEW THE WIKI e.g:**
>
> https://dev.azure.com/richardfennell/Git%20project/_wiki/wikis/Git-project.wiki/1/Home
>
> **SO DON'T USE THIS FORM**

To find the correct URL to clone the repo, and use it as the parameter for this task

1. Load the WIKI in a browser
1. At the top of the menu pane there is a menu (click the ellipsis ...)
1. Select the 'Clone repo' option
1. You will get a URL in the form https://richardfennell@dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki. This is the URL needed

### GitHub

Again, as with Azure DevOps, the URL to clone a GitHb WIKI also is not the one shown in the browser when the WIKI is viewed.

> **THIS IS NOT THE ONE YOU WANT**
>
> https://github.com/rfennell/AzurePipelines/wiki
>
> **SO DON'T USE IT**

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

1. Set the task's `UseAgentToken` parameter to true (if on Classic Build or Release, this defaults enabled for YAML)
1. Allow the pipeline to access th OAUTH Token
   - For UI based pipelines this is [documented here](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands)
   - For YAML based pipelines the OAUTH token should automatically be available
1. Grant 'contribute' access on the target Azure DevOps WIKI Repo to user the build agent is scoped to run as
   - Control of the scope the build agent runs as is [documented here](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope).
   - Usually this is the '_Project Name_ Build Service' user (assuming this is the account the pipeline is running. The alternative if the wider scope is used is the 'Project Collection Build Service' user
1. Make sure that the 'Project Collection > Setting > Pipeline > Setting > Protect access to repositories in YAML pipelines' as not enabled. If set it can block access to the target repo.

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
- If you see the error `Failure processing application bundle. Bundle header version compatibility check failed. A fatal error occured while processing application bundle`, you probably need to install NET6 on the agent (see above)
- If you are using a self hosted agent and the task cannot download the command line tool, make use the agent is able to communicate with the following Internet endpoints: __github.com__,__objects.githubusercontent.com__ and __storage.googleapis.com__. If this is not possible due to corporate firewall rules, swap to using a locally stored copy of the command line tool (See Section: How the AzureDevOps.WikiPDFExport tool is obtained)

