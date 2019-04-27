This set of tasks perform WIKI management operations

## Update a WIKI Page

The WIKI Updater task allows the updating of a Git based WIKI using an inputted string as the file data. This can be usefully paired with my [Generate Release Notes Extension](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-XplatGenerateReleaseNotes)

This can be used with both Azure DevOps and GitHub hosted WIKIs

### Usage

Add the task to a build or release

#### Required Parameters
- Repo - The repo URL to update e.g **dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki**
- Filename - The file (page to save/update) e.g. page.md
- Contents - The text to save in the file, can be the output from another task passed as pipelien variable
- Message - The Git commit message
- GitName - The name for the .gitatrributes file e.g. _builduser_
- GitEmail - The email for the .gitatrributes file e.g. _builduser@domain_

### Authentication

- UseAgentToken - If true the task will use the built in agent OAUTH token, if false you need to provide username & password/PAT". **Note** for use of the OAUTH token to work you must allow the pipeline to access the [OAUTH Token](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/git-commands?view=vsts&tabs=yaml#enable-scripts-to-run-git-commands) and grant _contribute_ access to target Azure DevOps WIKI to the _Project Collection Build Service_ user (assuming this is the account the pipeline is running as). The default is _false_
- Username - The username to autneticate with the repo (see below)
- Passsword - The password or PAT to autneticate with the repo (see below) _Recommended stored as secret variable_

The URL used for connection to the repo is in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

If using the OAUTH token then the **${user}** and the **${password}** are managed by the task. However they can be manually managed.

#### GitHub

For GitHub if using 2FA then the **${user}** is you Git account name and the **${password}** is your [PAT](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)

#### Azure DevOps

For Azure DevOps then the **${user}** is you organisation account name and the **${password}** is your [PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts)


#### Advanced

- LocalPath - The path used to clone the repo to for updating. Defaults to $(System.DefaultWorkingDirectory)\\repo

