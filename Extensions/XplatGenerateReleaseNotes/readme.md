# Releases
Generates release notes for a build or release. the file can be a format of your choice
* Can be used on any type of Azure DevOps Agents (Windows, Mac or Linux)
* For releases, uses same logic as Azure DevOps Release UI to work out the work items and commits/changesets associated with the release
* 3.24.x adds PR labels/tags to th
* 3.21.x adds an override for the historic pipeline to compare against
* 3.8.x adds currentStage variable for multi-stage YAML based builds
* 3.6.x adds compareBuildDetails variable for YAML based builds
* 3.5.x removed the need to enable OAUTH access for the Agent phase
* 3.4.x adds support for getting full commit messages from Bitbucket
* 3.1.x adds support for looking for the last successful stage in a multi-stage YAML pipeline. For this to work the stage name must be unique in the pipeline
* 3.0.x drops support for the legacy template model, only handlebars templates supported.
* The Azure DevOps REST APIs have a limitation that by default they only return 200 items. As a release could include more Work Items or ChangeSets/Commits. A workaround for this has been added [#349](https://github.com/rfennell/AzurePipelines/issues/349). Since version 2.12.x this feature has been defaulted on. To disable it set the variable `ReleaseNotes.Fix349` to `false`

**IMPORTANT** - There have been three major versions of this extension, this is because
* V1 which used the preview APIs and is required if using TFS 2018 as this only has older APIs. This version is not longer shipped in the extension, but can be download from [GitHub](https://github.com/rfennell/AzurePipelines/releases/tag/XPlat-2.6.9)
* V2 was a complete rewrite by [@gregpakes](https://github.com/gregpakes) using the Node Azure DevOps SDK, with minor but breaking changes in the template format and that oAuth needs enabling on the agent running the tasks. At 2.27.x KennethScott](https://github.com/KennethScott) added support for [Handlbars](https://handlebarsjs.com/) templates.
* V3 removed support for the legacy template model, only handlebars templates supported.

# Usage
This task generates a release notes file based on a template passed into the tool. It can be using inside a UI based Build or Release or a Multistage YAML Pipeline.

The data source for the generated Release Notes is the Azure DevOps REST API's comparison calls that are also used by the Azure DevOps UI to show the associated Work items and commit/changesets between two releases. Hence this task should generate the same list of items as the Azure DevOps UI. 

**Note:** That this comparison is only done against the primary build artifact linked to the Release

If used in the build or non-multistage YAML pipeline the release notes are based on the current build only.

## The Template 

There are [sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) that just produce basic releases notes for both Git and TFVC based releases. Most samples are for Markdown file generation, but it is possible to generate any other format such as HTML

<hr/>

**The legacy templating format has been be deprecated in V3. The only templating model supported is handlebars**
<hr/>

### Handlebar Templates
Since 2.27.x it has been possible to create your templates using [Handlebars](https://handlebarsjs.com/) syntax. A template written in this format is as follows

```
# Notes for release  {{releaseDetails.releaseDefinition.name}}    
**Release Number**  : {{releaseDetails.name}}
**Release completed** : {{releaseDetails.modifiedOn}}     
**Build Number**: {{buildDetails.id}}
**Compared Release Number**  : {{compareReleaseDetails.name}}    
**Build Trigger PR Number**: {{lookup buildDetails.triggerInfo 'pr.number'}} 

## Associated Pull Requests ({{pullRequests.length}})
{{#forEach pullRequests}}
* **[{{this.pullRequestId}}]({{replace (replace this.url "_apis/git/repositories" "_git") "pullRequests" "pullRequest"}})** {{this.title}}
{{#forEach this.associatedWorkitems}}
   {{#with (lookup_a_work_item ../../relatedWorkItems this.url)}}
    - WI [{{this.id}}]({{replace this.url "_apis/wit/workItems" "_workitems/edit"}}) - {{lookup this.fields 'System.Title'}} 
   {{/with}}
{{/forEach}}
{{/forEach}}

# Builds with associated WI/CS/Tests ({{builds.length}})
{{#forEach builds}}
{{#if isFirst}}## Builds {{/if}}
##  Build {{this.build.buildNumber}}
{{#forEach this.commits}}
{{#if isFirst}}### Commits {{/if}}
- CS {{this.id}}
{{/forEach}}
{{#forEach this.workitems}}
{{#if isFirst}}### Workitems {{/if}}
- WI {{this.id}}
{{/forEach}} 
{{#forEach this.tests}}
{{#if isFirst}}### Tests {{/if}}
- Test {{this.id}} 
   -  Name: {{this.testCase.name}}
   -  Outcome: {{this.outcome}}
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


```

**IMPORTANT** Handlebars based templates have different objects available to the legacy template.

What is done behind the scenes is that each `{{properties}}` block in the template is expanded by Handlebars. The property objects available to get data from at runtime are:

#### Common objects 
* **workItems** – the array of work item associated with the release
* **commits** – the array of commits/changesets associated with the release
* **pullRequests** - the array of PRs (inc. labels) referenced by the commits in the release
* **tests** - the array of unique tests associated with any of the builds linked to the release or the release itself  
* **builds** - the array of the build artifacts that CS and WI are associated with. Note that this is a object with three properties 
    - **build**  - the build details
    - **commits**  - the commits associated with this build
    - **workitems**  - the work items associated with the build
    - **tests**  - the work items associated with the build
* **relatedWorkItems** – the array of all work item associated with the release plus their direct parents or children and/or all parents depending on task parameters

#### Release objects (only available in a UI based Releases)
* **releaseDetails** – the release details of the release that the task was triggered for.
* **compareReleaseDetails** - the the previous successful release that comparisons are being made against
* **releaseTest** - the list of test associated with the release e.g. integration tests

#### Build objects (available for UI based builds and any YAML based pipelines)
* **buildDetails** – if running in a build, the build details of the build that the task is running in. If running in a release it is the build that triggered the release. 
* **compareBuildDetails** - the previous successful build that comparisons are being made against, only available if checkstage=true
* **currentStage** - if `checkstage` is enable this object is set to the details of the stage in the current build that is being used for the stage check

**Note:** To dump all possible values via the template using the custom Handlebars extension `{{json propertyToDump}}` this runs a custom Handlebars extension to do the expansion. There are also options to dump these raw values to the build console log or to a file. (See below)

**Note:** if a field contains escaped HTML encode data this can be returned its original format with triple brackets format `{{{lookup this.fields 'System.Description'}}}` 

#### Handlebar Extensions
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

and can be consumed in a template as shown below
```
## To confirm our custom extension works
We can call our custom extension {{foo}}
```

As custom modules allows any JavaScript logic to be inject for bespoke need they can be solution to your own bespoke filtering and sorting needs. You can find sample of custom modules [the the Handlebars section of the sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) e.g. to perform a sorted foreach.

## Usage
Once the extension is added to your Azure DevOps Server (TFS) or Azure DevOps Services, the task should be available in the utilities section of 'add tasks'

**IMPORTANT** - The V2 Task requires that oAuth access is enabled on agent running the task, this requirement has been removed in V3

The task takes the following parameters

* The output file name, for builds this will normally be set to `$(Build.ArtifactStagingDirectory)\releasenotes.md` as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like `$(System.DefaultWorkingDirectory)\releasenotes.md`. Where you choose to send the created files is down to your deployment needs.
* A picker allows you to set if the template is provided as a file in source control or an inline file. The setting of this picker effects which other parameters are shown
    * Either, the template file name, which should point to a file in source control.
    * Or, the template text.
* Check Stage - If true a comparison is made against the last build that was successful to the current stage, or overrideStageName if specified (Build Only)
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Name of the release stage to look for the last successful release in, defaults to empty value so uses the current stage of the release that the task is running in.
* (Advanced) Do not generate release notes of a re-deploy. If this is set, and a re-deploy occurs the task will succeeds with a warning
* (Advanced) Primary Only. If this is set only WI and CS associated with primary artifact are listed, default is false so all artifacts scanned.
* (Advanced) Replace File. If this is set the output overwrites and file already present.
* (Advanced) Append To File. If this is set, and replace file is false then then output is appended to the output file. If false it is preprended.
* (Advanced) Cross Project For PRs. If true will try to match commits to Azure DevOps PR cross project within the organisation, if false only searches the Team Project.
* (Advanced) Override Stage Name. If set uses this stage name to find the last successful deployment, as opposed to the currently active stage
* (Advanced) GitHub PAT. (Optional) This [GitHub PAT](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) is only required to expand commit messages stored in a private GitHub repos. This PAT is not required for commit in Azure DevOps public or private repos or public GitHub repos
* (Advanced) BitBucket User (Optional) To expand commit messages stored in a private Bitbucket repos a [BitBucker user and app password](https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/) need to be provided, it is not required for repo stored in Azure DevOps or public Bitbucket repos.
* (Advanced) BitBucket Password (Optional) See BitBucket User documentation above
* (Advanced) Dump Payload to Console - If true the data objects passed to the file generator is dumped to the log.
* (Advanced) Dump Payload to File - If true the data objects passed to the file generator is dumped to a JSON file.
* (Advanced) Dump Payload Filename - The filename to dump the data objects passed to the file generator
* (Advanced) Get Direct Parent and Children for associated work items, defaults to false
* (Advanced) Get All Parents for associated work items, recursing back to workitems with no parents e.g. up to Epics, defaults to false
* (Advanced) Tags - a comma separated list of pipeline tags that must all be matched when looking for previous successful builds , only used if checkStage=true
* (Advanced) OverridePat - a means to inject a Personal Access Token to use in place of the Build Agent OAUTH token. This option will only be used in very rare situations usually after a support issue has been raised, defaults to empty
* (Advanced) OverrideBuildReleaseId - For releases or multi-stage YAML this parameter provides a means to set the ID of the 'last good release' to compare against. If the specified release/build is not found then the task will exit with an error. The override behaviour is as follows
   * (Default) Parameter undefined - Old behaviour, looks for last successful build using optional stage and tag filters
   * Empty string - Old behaviour, looks for last successful build using optional stage and tag filters
   * A valid build ID (int) - Use the build ID as the comparison
   * An invalid build ID (int) -	If a valid build cannot be found then the task exits with a message
   * Any other non empty input value - The task exits with an error message
* (Handlebars) customHandlebars ExtensionCode. A custom Handlebars extension written as a JavaScript module e.g. module.exports = {foo: function () {return 'Returns foo';}};
* (Outputs) Optional: Name of the variable that release notes contents will be copied into for use in other tasks. As an output variable equates to an environment variable, so there is a limit on the maximum size. For larger release notes it is best to save the file locally as opposed to using an output variable.

## Output location ##

When using this task within a build then it is sensible to place the release notes files as a build artifacts.

However, within a release there are no such artifacts location. Hence, it is recommended that a task such as the [WIKI Updater](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-WIKIUpdater-Tasks) is used to upload the resultant file to a WIKI. Though there are other options such as store the file on a UNC share, in an Azure DevOps Artifact or sent as an email.


# Local Testing of the Task & Templates
To speed the development of templates, with version 2.50.x, a [tool](https://github.com/rfennell/AzurePipelines/tree/master/Extensions/XplatGenerateReleaseNotes/V3/testconsole/readme.md) is provided in this repo to allow local testing.

Also there are now parameters (see above) to dump all the REST API payload data to the console or a file to make discovery of the data available in a template easier.