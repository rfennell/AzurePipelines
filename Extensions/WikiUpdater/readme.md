This set of tasks perform WIKI management operations

## Update a WIKI Page

The WIKI Updater task allows the updating of a Git based WIKI using an inputted string as the file data. This can be usefully paired with my [Generate Release Noted Extension](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-XplatGenerateReleaseNotes)

This can be used with both Azure DevOps and GitHub WIKIs

###Usage

Add the task to a build or release

#### Required Parameters
- Repo - The repo URL to clone e.g **dev.azure.com/richardfennell/Git%20project/_git/Git-project.wiki**
- Filename - The file (page to save/update) e.g. page.md
- Contents - The text to save in the file, canbe the output from another task
- Message - The Git commit message
- GitName - The name for the .gitatrributes file
- GitEmail - The email for the .gitatrributes file
- Username - The username to autneticate with the repo (see below)
- Passsword - The password or PAT to autneticate with the repo (see below) _Recommended stored as secret variable_

#### Advanced
- LocalPath - The path used to clone the repo to for updating. Defaults to $(System.DefaultWorkingDirectory)\\repo

## Authentication

The URL used for conenction to the repo is in the form

```
const remote = `https://${user}:${password}@${repo}`;
```

### GitHub
For GitHub if using 2FA then the **${user}** is you Git account name and the **${password}** is your [PAT](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)

### Azure DevOps
For Azure DevOps then the **${user}** is you organisation account name and the **${password}** is your [PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts)

**Note**: Enhanced feature will used the built in task token in a later build

## Releases

- 1.0 Initial release
