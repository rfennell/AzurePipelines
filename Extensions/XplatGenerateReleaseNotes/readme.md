# Releases
Generates release notes for a Classic Build or Release, or a YML based build. The generated file can be any text based format of your choice
* Can be used on any type of Azure DevOps Agents (Windows, Mac or Linux)
* Uses same logic as Azure DevOps Release UI to work out the work items and commits/changesets associated with the release
* 3.54.x Added support to find WI linked from GitHub using the `AB#123` syntax and adding them to the `workitems` array
* 3.52.x Added enrichement of pipeline `consumedArtifacts` to include commits and workitem associated where possible
* 3.50.x Added `consumedArtifacts` to the available options in the template
* 3.46.x Added `manualtest` and `manualTestConfigurations` to the available options in the template
* 3.32.x Adds parameters to control the retry logic for timed outed out API calls
* 3.28.x provide a new array of `inDirectlyAssociatedPullRequests`, this contains PR associated with a PR's associated commits. Useful if using a Gitflow work work-flow [x866](https://github.com/rfennell/AzurePipelines/issues/866) (see sample template below)
* 3.27.x enriches the PR with associated commits (see sample template below)
* 3.25.x enriches the PR with associated work items references (you need to do a lookup into the list of work items to get details, see sample template below)
* 3.24.x adds labels/tags to the PR 
* 3.21.x adds an override for the historic pipeline to compare against
* 3.8.x adds `currentStage` variable for multi-stage YAML based builds
* 3.6.x adds `compareBuildDetails` variable for YAML based builds
* 3.5.x removed the need to enable OAUTH access for the Agent phase
* 3.4.x adds support for getting full commit messages from Bitbucket
* 3.1.x adds support for looking for the last successful stage in a multi-stage YAML pipeline. For this to work the stage name must be unique in the pipeline
* 3.0.x drops support for the legacy template model, only handlebars templates supported.
* The Azure DevOps REST APIs have a limitation that by default they only return 200 items. As a release could include more Work Items or ChangeSets/Commits. A workaround for this has been added [#349](https://github.com/rfennell/AzurePipelines/issues/349). Since version 2.12.x this feature has been defaulted on. To disable it set the variable `ReleaseNotes.Fix349` to `false`

> **IMPORTANT** - There have been three major versions of this extension, this is because
> * V1 which used the preview APIs and is required if using TFS 2018 as this only has older APIs. This version is not longer shipped in the extension, but can be download from [GitHub](https://github.com/rfennell/AzurePipelines/releases/tag/XPlat-2.6.9)
> * V2 was a complete rewrite by [@gregpakes](https://github.com/gregpakes) using the Node Azure DevOps SDK, with minor but breaking changes in the template format and that oAuth needs enabling on the agent running the tasks. At 2.27.x [KennethScott](https://github.com/KennethScott) added support for [Handlbars](https://handlebarsjs.com/) templates.
> * V3 removed support for the legacy template model, only handlebars templates supported as this is a far more flexible solution and allow much easier enhancement of this task

# Overview
This task generates a release notes file based on a template passed into the tool. It can be using inside a [classic Build, a classic Release](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-get-started?view=azure-devops#define-pipelines-using-the-classic-interface) or a [Multistage YAML Pipeline](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-get-started?view=azure-devops#define-pipelines-using-yaml-syntax).

The data source for the generated Release Notes is the Azure DevOps REST API's comparison calls that are also used by the Azure DevOps UI to show the associated Work items and commit/changesets between two releases. Hence this task should generate the same list of work items and commits/changesets as the Azure DevOps UI, though it can enrich this core data with extra information. 

> **Note:** 
>  - That this comparison is only done against the primary build artifact linked to a Classic Release
>  - If used in the build or non-multistage YAML pipeline the release notes are based on the current build only.

There are many ways that the task can be used. A common pattern is to use the task multiple times in a pipeline

1. Run once for every build, so you get the build notes of what is in that build
1. Run as part of a deployment stage, checking against the last successful deployment to that stage, to generate the release notes specific to that release.

Possible sets of parameters depending on your usage are summarized below

| Option | Multi Stage YAML | Classic Build/Release |
|-|-|-|
| Generate notes for just the current build | Requires `checkstages=false` parameter| Run inside the build |
| Generate notes since the last successful release.  <br>Option 1. Place the task in a stage that is only run when you wish to generate release notes. Usually this will be guarded by branch based filters or manual approvals.  |  Requires `checkstages=true` parameter | Run inside the release. Supported and you can override the stage name used for comparison using the `overrideStageName` parameter
| Generate notes since the last successful release.  <br>Option 2. Set the task to look back for the last successful build that has a given tag |  Requires `checkstages=true` and the `tags` parameters| Not supported 
| Generate notes since the last successful release.  <br>Option 3. Override the build that the task uses for comparison with a fixed value |  Requires `checkstages=true` and the `overrideBuildReleaseId` parameters | Run inside the release. Requires the `overrideBuildReleaseId` parameter

You can see the documentation for all the features in the [WIKI ](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task) and the YAML usage [here](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task-YAML)


# The Template 

There are [sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) that just produce basic releases notes for both Git and TFVC based releases. Most samples are for Markdown file generation, but it is possible to generate any other format such as HTML

<hr/>

**Note** The legacy templating format has been be deprecated in V3. The only templating model supported is Handlebars
<hr/>

## Handlebar Templates
Since 2.27.x it has been possible to create your templates using [Handlebars](https://handlebarsjs.com/) syntax. A template written in this format is as follows

```
## Build {{buildDetails.buildNumber}}
* **Branch**: {{buildDetails.sourceBranch}}
* **Tags**: {{buildDetails.tags}}
* **Completed**: {{buildDetails.finishTime}}
* **Previous Build**: {{compareBuildDetails.buildNumber}}

## Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
* **[{{this.pullRequestId}}]({{replace (replace this.url "_apis/git/repositories" "_git") "pullRequests" "pullRequest"}})** {{this.title}}
* Associated Work Items
{{#forEach this.associatedWorkitems}}
   {{#with (lookup_a_work_item ../../relatedWorkItems this.url)}}
    - [{{this.id}}]({{replace this.url "_apis/wit/workItems" "_workitems/edit"}}) - {{lookup this.fields 'System.Title'}} 
   {{/with}}
{{/forEach}}
* Associated Commits (this includes commits on the PR source branch not associated directly with the build)
{{#forEach this.associatedCommits}}
    - [{{this.commitId}}]({{this.remoteUrl}}) -  {{this.comment}}
{{/forEach}}
{{/forEach}}

# Global list of WI with PRs, parents and children
{{#forEach this.workItems}}
{{#if isFirst}}### WorkItems {{/if}}
*  **{{this.id}}**  {{lookup this.fields 'System.Title'}}
   - **WIT** {{lookup this.fields 'System.WorkItemType'}} 
   - **Tags** {{lookup this.fields 'System.Tags'}}
   - **Assigned** {{#with (lookup this.fields 'System.AssignedTo')}} {{displayName}} {{/with}}
   - **Description** {{{lookup this.fields 'System.Description'}}}
   - **PRs**
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Pull Request')}}
{{#with (lookup_a_pullrequest ../../pullRequests  this.url)}}
      - {{this.pullRequestId}} - {{this.title}} 
{{/with}}
{{/if}}
{{/forEach}} 
   - **Parents**
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Parent')}}
{{#with (lookup_a_work_item ../../relatedWorkItems  this.url)}}
      - {{this.id}} - {{lookup this.fields 'System.Title'}} 
      {{#forEach this.relations}}
      {{#if (contains this.attributes.name 'Parent')}}
      {{#with (lookup_a_work_item ../../../../relatedWorkItems  this.url)}}
         - {{this.id}} - {{lookup this.fields 'System.Title'}} 
      {{/with}}
      {{/if}}
      {{/forEach}} 
{{/with}}
{{/if}}
{{/forEach}} 
   - **Children**
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Child')}}
{{#with (lookup_a_work_item ../../relatedWorkItems  this.url)}}
      - {{this.id}} - {{lookup this.fields 'System.Title'}} 
{{/with}}
{{/if}}
{{/forEach}} 
{{/forEach}}

# Global list of CS ({{commits.length}})
{{#forEach commits}}
{{#if isFirst}}### Associated commits{{/if}}
* ** ID{{this.id}}** 
   -  **Message:** {{this.message}}
   -  **Commited by:** {{this.author.displayName}} 
   -  **FileCount:** {{this.changes.length}} 
{{#forEach this.changes}}
      -  **File path (TFVC or TfsGit):** {{this.item.path}}  
      -  **File filename (GitHub):** {{this.filename}}  
{{/forEach}}
{{/forEach}}

## Manual Test Plans
| Run ID | Name | State | Total Tests | Passed Tests |
| --- | --- | --- | --- | --- |
{{#forEach manualTests}}
| [{{this.id}}]({{this.webAccessUrl}}) | {{this.name}} | {{this.state}} | {{this.totalTests}} | {{this.passedTests}} |
{{/forEach}}

## Global list of ConsumedArtifacts ({{consumedArtifacts.length}})
| Category | Type | Version Name | Version Id | Commits | Workitems |
|-|-|-|-|-|-|
{{#forEach consumedArtifacts}}
 |{{this.artifactCategory}} | {{this.artifactType}} | {{#if versionName}}{{versionName}}{{/if}} | {{truncate versionId 7}} | {{#if this.commits}} {{this.commits.length}} {{/if}} | {{#if this.workitems}} {{this.workitems.length}} {{/if}} |
{{/forEach}}

```

> **IMPORTANT** Handlebars based templates have different objects available to the legacy template used in V2 of this extension. This is a break change, so what out if migrating

> **IMPORTANT** You can find more sample templates and extensions [here](https://github.com/rfennell/AzurePipelines/tree/main/SampleTemplates/XplatGenerateReleaseNotes%20(Node%20based)/Version%203)


What is done behind the scenes is that each `{{properties}}` block in the template is expanded by Handlebars. The property objects available to get data from at runtime are:

## Common objects 
| Object | Description |
| -| -|
|**workItems** | the array of work item associated with the release|
|**commits** | the array of commits/changesets associated with the build/release |
| **pullRequests** | the array of PRs (inc. labels, associated WI links and commits to the source branch) referenced by the commits in the release|
| **inDirectlyAssociatedPullRequests** | the array of PRs (inc. labels, associated WI links and commits to the source branch) referenced by associated commits of the directly linked PRs. [#866](https://github.com/rfennell/AzurePipelines/issues/866) |
|**tests** | the array of unique automated tests associated with any of the builds linked to the release or the release itself  |
|**manualtests** | the array of manual Test Plan runs associated with any of the builds linked to the release |
|**manualTestConfigurations** | the array of manual test configurations |
| **relatedWorkItems** | the array of all work item associated with the release plus their direct parents or children and/or all parents depending on task parameters |

### Release objects (only available in a Classic UI based Releases)
| Object | Description |
| -| -|
| **releaseDetails** | the release details of the release that the task was triggered for.|
| **compareReleaseDetails** | the the previous successful release that comparisons are being made against |
| **releaseTest** | the list of test associated with the release e.g. integration tests |
| **builds** | the array of the build artifacts that CS and WI are associated with. The associated WI, CS etc. in ths object are also will the main objects above, this is a filtered lits by build. Note that this is a object with multiple child properties. <br> - **build**  - the build details <br> -- **commits**  - the commits associated with this build <br> -- **workitems**  - the work items associated with the build<br> -- **tests**  - the work items associated with the build <br> -- **manualtests**  - the manual test runs associated with the build

### Build objects (available for Classic UI based builds and any YAML based pipelines)
| Object | Description |
| -| -|
| **buildDetails** | if running in a build, the build details of the build that the task is running in. If running in a release it is the build that triggered the release. 
| **compareBuildDetails** | the previous successful build that comparisons are being made against, only available if `checkstage=true`
| **currentStage** | if `checkstage` is enable this object is set to the details of the stage in the current build that is being used for the stage check
| **consumedArtifacts** | the artifacts consumed by the pipeline, enriched with details of commits and workitems if available

> **Note:** To dump all possible values via the template using the custom Handlebars extension `{{json propertyToDump}}` this runs a custom Handlebars extension to do the expansion. There are also options to dump these raw values to the build console log or to a file. (See below)

> **Note:** if a field contains escaped HTML encode data this can be returned its original format with triple brackets format `{{{lookup this.fields 'System.Description'}}}` 

## Handlebar Extensions
With 2.28.x support was added for Handlebars extensions in a number of ways:

 The [Handlebars Helpers](https://github.com/helpers/handlebars-helpers) extension library is also pre-load, this provides over 120 useful extensions to aid in data manipulation when templating. They are used the form

```
## To confirm the Handlebars-helpers is work
The year is {{year}} 
We can capitalize "foo bar baz" {{capitalizeAll "foo bar baz"}}
```

In addition to the [Handlebars Helpers](https://github.com/helpers/handlebars-helpers) extension library, there is also custom Helpers pre-loaded specific to the needs of this Azure DevOps task

- `json` that will dump the contents of any object. This is useful when working out what can be displayed in a template, though there are other ways to dump objects to files (see below)

```
## The contents of the build object
{{json buildDetails}}
```

- `lookup_a_work_item` this looks up a work item in the global array of work items based on a work item relations URL
```
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Parent')}}
{{#with (lookup_a_work_item ../../relatedWorkItems  this.url)}}
      - {{this.id}} - {{lookup this.fields 'System.Title'}} 
      {{#forEach this.relations}}
      {{#if (contains this.attributes.name 'Parent')}}
      {{#with (lookup_a_work_item ../../../../relatedWorkItems  this.url)}}
         - {{this.id}} - {{lookup this.fields 'System.Title'}} 
      {{/with}}
      {{/if}}
      {{/forEach}} 
{{/with}}
{{/if}}
{{/forEach}} 
```

```
## Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
* **[{{this.pullRequestId}}]({{replace (replace this.url "_apis/git/repositories" "_git") "pullRequests" "pullRequest"}})** {{this.title}}
* Associated Work Items
{{#forEach this.associatedWorkitems}}
   {{#with (lookup_a_work_item ../../relatedWorkItems this.url)}}
    - [{{this.id}}]({{replace this.url "_apis/wit/workItems" "_workitems/edit"}}) - {{lookup this.fields 'System.Title'}} 
   {{/with}}
{{/forEach}}
* Associated Commits (this s commits on the PR source branch not associated directly with the build)
{{#forEach this.associatedCommits}}
    - [{{this.commitId}}]({{this.remoteUrl}}) -  {{this.comment}}
{{/forEach}}
{{/forEach}}
```

- `lookup_a_pullrequest` this looks up a pull request item in the global array of pull requests based on a work item relations URL
```
{{#forEach this.relations}}
{{#if (contains this.attributes.name 'Pull Request')}}
{{#with (lookup_a_pullrequest ../../pullRequests  this.url)}}
      - {{this.pullRequestId}} - {{this.title}} 
{{/with}}
{{/if}}
{{/forEach}}
```

- `get_only_message_firstline` this gets just the first line of a multi-line commit message
- `lookup_a_pullrequest_by_merge_commit` this looks up a pull request item in an array of pull requests based on a last merge commit ID
```
## Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
* **[{{this.pullRequestId}}]({{replace (replace this.url "_apis/git/repositories" "_git") "pullRequests" "pullRequest"}})** {{this.title}}
* Associated Work Items
{{#forEach this.associatedWorkitems}}
   {{#with (lookup_a_work_item ../../relatedWorkItems this.url)}}
    - [{{this.id}}]({{replace this.url "_apis/wit/workItems" "_workitems/edit"}}) - {{lookup this.fields 'System.Title'}} 
   {{/with}}
{{/forEach}}
* Associated Commits (this includes commits on the PR source branch not associated directly with the build)
{{#forEach this.associatedCommits}}
    - [{{truncate this.commitId 7}}]({{this.remoteUrl}}) - {{get_only_message_firstline this.comment}}
    {{#with (lookup_a_pullrequest_by_merge_commit ../../inDirectlyAssociatedPullRequests  this.commitId)}}
      - Associated PR {{this.pullRequestId}} - {{this.title}} 
    {{/with}}
{{/forEach}}
{{/forEach}}
```
- `lookup_a_test_configuration` this gets the test configuration related to a manual test
```
## Manual Test Plans with test details
{{#forEach manualTests}}
### [{{this.id}}]({{this.webAccessUrl}}) {{this.name}} - {{this.state}}

| Test | Outcome | Configuration |
| - | - | - |
{{#forEach this.TestResults}}
| {{this.testCaseTitle}} | {{this.outcome}} | {{#with (lookup_a_test_configuration ../../manualTestConfigurations this.configuration.id)}} {{this.name}} {{/with}} |
{{/forEach}}
{{/forEach}}
```

Finally there is also support for your own custom extension libraries. These are provided via an Azure DevOps task parameter holding a block of JavaScript which is loaded into the Handlebars templating engine. They are entered in the YAML as a single line or a multi-line parameter as follows using the `|` operator

```
- task: XplatGenerateReleaseNotes@3
   inputs:
      outputfile: '$(Build.ArtifactStagingDirectory)\releasenotes.md'
      # all the other parameters required
      customHandlebarsExtensionCode: |
         module.exports = {foo() {
            return 'Returns foo';
         }};
```

Or the custom extension can be passed as file 

```
- task: XplatGenerateReleaseNotes@3
   inputs:
      outputfile: '$(Build.ArtifactStagingDirectory)\releasenotes.md'
      # all the other parameters required
      customHandlebarsExtensionFile: $(System.SourceDirectory)\customcode.js
```

Either way it can be consumed in a template as shown below
```
## To confirm our custom extension works
We can call our custom extension {{foo}}
```

As custom modules allows any JavaScript logic to be inject for bespoke need they can be solution to your own bespoke filtering and sorting needs. You can find sample of custom modules [the the Handlebars section of the sample templates](https://github.com/rfennell/AzurePipelines/tree/main/SampleTemplates/XplatGenerateReleaseNotes%20(Node%20based)/Version%203) e.g. to perform a sorted foreach.

# Task Parameters
Once the extension is added to your Azure DevOps Server (TFS) or Azure DevOps Services, the task should be available in the utilities section of 'add tasks'

> **IMPORTANT** - The V2 Task requires that oAuth access is enabled on agent running the task, this requirement has been removed in V3

The task takes the following parameters

| Parameter | Description |
|-|-|
| OutputFile | for builds this will normally be set to `$(Build.ArtifactStagingDirectory)\releasenotes.md` as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like `$(System.DefaultWorkingDirectory)\releasenotes.md`. Where you choose to send the created files is down to your deployment needs. |
| templateLocation | A picker allows you to set if the template is provided as a file in source control or an inline file. The setting of this picker effects which other parameters are shown. Either, the template file name, which should point to a file in source control, or, the template text. |
| CheckStage | If true a comparison is made against the last build that was successful to the current stage, or overrideStageName if specified (Build Only) |
| EmptySetText | the text to place in the results file if there is no changeset/commit or WI content |
| stopOnRedeploy | Do not generate release notes of a re-deploy. If this is set, and a re-deploy occurs the task will succeeds with a warning |
| showOnlyPrimary | If this is set only WI and CS associated with primary artifact are listed, default is false so all artifacts scanned. |
| ReplaceFile | If this is set the output overwrites and file already present.Z
| AppendToFile |If this is set, and replace file is false then then output is appended to the output file. If false it is preprended. |
| searchCrossProjectForPRs |If true will try to match commits to Azure DevOps PR cross project within the organisation, if false only searches the Team Project.|
| OverrideStageName |If set uses this stage name to find the last successful deployment, as opposed to the currently active stage |
| GitHubPAT. | (Optional) This [GitHub PAT](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) is only required to expand commit messages stored in a private GitHub repos. This PAT is not required for commit in Azure DevOps public or private repos or public GitHub repos|
| BitBucketUser | (Optional) To expand commit messages stored in a private Bitbucket repos a [BitBucker user and app password](https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/) need to be provided, it is not required for repo stored in Azure DevOps or public Bitbucket repos.|
|BitBucketPassword| (Optional) See BitBucket User documentation above|
| DumpPayloadToConsole | If true the data objects passed to the file generator is dumped to the log.|
| DumpPayloadToFile | If true the data objects passed to the file generator is dumped to a JSON file.|
| DumpPayloadFilename | The filename to dump the data objects passed to the file generator|
| getParentsAndChildren |Get Direct Parent and Children for associated work items, defaults to false|
| getAllParents | Get All Parents for associated work items, recursing back to workitems with no parents e.g. up to Epics, defaults to false |
|Tags | A comma separated list of pipeline tags that must all be matched when looking for previous successful builds , only used if checkStage=true |
| OverridePat | A means to inject a Personal Access Token to use in place of the Build Agent OAUTH token. This option will only be used in very rare situations usually after a support issue has been raised, defaults to empty|
| getIndirectPullRequests | If enabled an attempt will be made to populate a list of indirectly associated PRs i.e PR that are associated with a PR's associated commits [#866](https://github.com/rfennell/AzurePipelines/issues/866)|
| OverrideBuildReleaseId | For releases or multi-stage YAML this parameter provides a means to set the ID of the 'last good release' to compare against. If the specified release/build is not found then the task will exit with an error. The override behaviour is as follows.<br>- (Default) Parameter undefined - Old behaviour, looks for last successful build using optional stage and tag filters <br>- Empty string - Old behaviour, looks for last successful build using optional stage and tag filters<br>- A valid build ID (int) - Use the build ID as the comparison<br>- An invalid build ID (int) -	If a valid build cannot be found then the task exits with a message <br>- Any other non empty input value - The task exits with an error message
| MaxRetries | The number of times to retry any REST API calls that timeout. Set to zero for no retries. Defaults to 20|
| stopOnError | If enabled will stop the pipeline if there is a Handlebars template error, if false the task will log the error but continue. Default: false |
| customHandlebarsExtensionCode | A string containing custom Handlebars extension written as a JavaScript module e.g. <br> `module.exports = {foo: function () {return 'Returns foo';}};`. <br>Note: If any text is set in this parameter it overwrites any contents of the customHandlebarsExtensionFile parameter |
| customHandlebarsExtensionFolder | The folder to look for, or create, the customHandlebarsExtensionFile in. If not set defaults to the task's current directory |
| customHandlebarsExtensionFile | The filename to save the customHandlebarsExtensionCode into if set. If there is no text in the  customHandlebarsExtensionCode parameter the an attempt will be made to load any custom extensions from from this file. This allows custom extensions to loaded like any other source file under source control. |
| outputVariableName | Name of the variable that release notes contents will be copied into for use in other tasks. As an output variable equates to an environment variable, so there is a limit on the maximum size. For larger release notes it is best to save the file locally as opposed to using an output variable.|

# Output location 

When using this task within a build then it is sensible to place the release notes files as a build artifacts.

However, within a release there are no such artifacts location. Hence, it is recommended that a task such as the [WIKI Updater](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-WIKIUpdater-Tasks) is used to upload the resultant file to a WIKI. Though there are other options such as store the file on a UNC share, in an Azure DevOps Artifact or sent as an email.


# Local Testing of the Task & Templates
To speed the development of templates, with version 2.50.x, a [tool](https://github.com/rfennell/AzurePipelines/tree/master/Extensions/XplatGenerateReleaseNotes/V3/testconsole/readme.md) is provided in this repo to allow local testing.

Also there are now parameters (see above) to dump all the REST API payload data to the console or a file to make discovery of the data available in a template easier.

# Troubleshooting

## Timeouts
This task makes many calls to the Azure DevOps REST API, the volume depends on the number of associated items with a build. This volume of calls can result in timeouts, it is assumed this is due to throttling by the API. If a timeout occurs the task fails with an error in the form

```
Error: connect ETIMEDOUT 13.107.42.18:443
```

This is an issue with the underlying Azure DevOps Node SDK or REST API endpoints, not this task. Hence, an issue has been raised in the the appropriate [Repo #425](https://github.com/microsoft/azure-devops-node-api/issues/425)

Historically the only workaround has been to always place this task, and any associated tasks e.g. one that upload the generated release notes to a WIKI, in a dedicated YML pipeline job. This allows the task to be easily retried without rerunning the whole pipeline. However, with 3.37.x the error traps have been changed in the task to treat any error that occurs whilst accessing the API as a warning, but allow the task to run on to try to generate any release notes it can with the data it has managed to get. This is far from perfect but a bit more robust.

## OAUTH Scope limiting what Associated Items can be seen
This task uses the build agent's access OAUTH token to access the Azure DevOps API. The permissions this identity has is dependant upon the [the Job authorization scope](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope).

Cross project permissions are made more complex by the new default settings for recently created Team Projects (created since late 2020). These can effect this task's operation why trying to find associated items from other Team Projects. 

> **Note** This setting is not a problem in older Team Projects, where the default setting to off

So, if you find that the `workItems` and `relatedWorkItems` objects are unexpectedly empty arrays when you expect values from other Team Projects check that the project settings:

`Project Settings > Pipelines > Limit job authorization scope to current project for release pipelines`

and

`Project Settings > Pipelines > Limit job authorization scope to current project for non-release pipelines`

they should both be set to `disabled`

> **Note** If you wish to confirm this is an issue you can inject a different PAT using the `overridePat` parameter. This PAT will be used in place of the OAUTH Token