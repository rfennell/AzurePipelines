# Summary
Generates a release notes markdown file using the same API calls as the Azure DevOps Pipeline Release UI
* Can be used on any type of release agents (Windows, Mac or linux)
* Can be used in Azure Devops Server and Service (***Note** TFS 2018 required as older V1 version are missing the required API, this is not in the marketplace, but can be downloaded from [here](https://github.com/rfennell/AzurePipelines/releases/tag/XPlat-2.6.9))
* Uses same logic as AZure DevOps Release UI to work out the work items and commits/changesets associated with the release
* **IMPORTANT** - There have been two major versions of this extension, this is because
   * V1 which used the preview APIs and is required if using TFS 2018 as this only has older APIs - is not longer shipped in extension
   * V2 is a complete rewrite by [@gregpakes](https://github.com/gregpakes) using the SDK, with minor but breaking changes in the template format and that oAuth needs enabling on the agent running the tasks .
* Since the V2 re-write, support has been added for tag filtering in the work items listed in a report. A report can have many WILOOPs with different filters. For a WI to appear in such a loop all tags must be matched.

# Usage
As with my original [PowerShell based Release Notes task](https://github.com/rfennell/vNextBuild/wiki/GenerateReleaseNotes--Tasks), this task generates a release notes file based on a template passed into the tool.  For this version of the task the data source for the generated Release Notes is the VSTS REST API's comparison calls that are also used by the VSTS UI to show the associated Work items and commit/changesets between two releases. Hence this task should generate the same list of items as the VSTS UI.

**Note:** That this comparison is only done against the primary build artifact linked to the Release, and this task can only be run inside a build

If the template file is markdown (other formats are possible) the output report being something like the following:

```
# Release notes
## Notes for release  New Empty Definition 25-Mar
**Release Number**  : Release-5
**Release completed** : 2017-04-03T19:32:25.76Z
**Compared Release Number**  : Release-4

### Associated work items
* ** Epic 21 ** Assigned by: Richard Fennell (Work MSA) <bm-richard.fennell@outlook.com>  Add items

### Associated commits
* **ID f5f964fe5ab27b1b312f6aa45ea1c5898d74358a ** Updated Readme.md #21
```

## The Template

There are [sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) that just produce basic releases notes for both Git and TFVC based releases for both V1 and V2 formats.

The use of a template allows the user to define the format, layout and fields shown in the release notes document. It is basically a file in the format required with tags to denote the fields to be replaced when the tool generates the report file.

- Most samples are in Markdown, but it is possible to generate any other format such as HTML
- The @@TAG@@ markers are special loop control flags
- The ${properties} are the fields to be expanded from properties in the JSON response objects returned from the VSTS REST API
- This task differed from [PowerShell based Release Notes task](https://github.com/rfennell/vNextBuild/wiki/GenerateReleaseNotes--Tasks) in that the ${properties} format changes slightly due to the move from PowerShell to Node within the task

The only real change from standard markdown is the use of the @@TAG@@ block markers to denote areas that should be looped over i.e: the points where we get the details of all the work items and commits associated with the build. So a template for GIT or TFVC (if using v2) repo could be

```
# Release notes
## Notes for release  ${releaseDetails.releaseDefinition.name}
**Release Number**  : ${releaseDetails.name}
**Release completed** : ${releaseDetails.modifiedOn}
**Compared Release Number**  : ${compareReleaseDetails.name}

### All associated work items
@@WILOOP@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP@@

### Associated work items that have both the tags 'Tag 1' and 'Tag2'
@@WILOOP:Tag 1:Tag2@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP:Tag 1:Tag2@@

### Associated commits
@@CSLOOP@@
* **ID ${csdetail.id} ** ${csdetail.message}
@@CSLOOP@@
```

**Note** for the V1 version there is a difference between GIT and TFVC templates

```

### Associated commits for Git
@@CSLOOP@@
* **ID ${csdetail.commitId} ** ${csdetail.comment}
@@CSLOOP@@
```

Whilst a TFVC repo requires

```
### Associated commits
@@CSLOOP@@
* **ID ${csdetail.changesetId} ** ${csdetail.comment}
@@CSLOOP@@
```


What is done behind the scenes is that each line of the template is evaluated as a line of Node.JS in turn, the in memory versions of the objects are used to provide the runtime values. The available objects to get data from at runtime are

* releaseDetails – the release details returned by the REST call Get Release Details of the release that the task was triggered for.
* compareReleaseDetails - the release that the REST call is using to comapre against
* widetail – the details of a given work item inside the loop returned by the REST call Get Work Item (within the @@WILOOP@@@ block) the : format can be used to specify tags to filter on (in V2)
* csdetail – the details of a given Git commit or TFVC changeset inside the loop returned by the REST call to Get Commits(within the @@CSLOOP@@@ block)


## Usage
Once the extension is added to your TFS or VSTS server, the task should be available in the utilities section of 'add tasks'

**IMPORTANT** - The V2 Tasks requires that oAuth access is enabled on agent running the task

The task takes three parameters

* The output file name, for builds this will normally be set to $(Build.ArtifactStagingDirectory)\releasenotes.md as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like $(System.DefaultWorkingDirectory)\releasenotes.md. Where you choose to send the created files is down to your deployment needs.
* A picker allows you to set if the template is provided as a file in source control (usually used for builds) or an inline file (usually used for release management). The setting of this picker effects which third parameter is shown
* Either - The template file name, which should point to a file in source control.
* Or - The template text.
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Name of the release stage to look for the last successful release in, default to empty value so uses the current stage of the release that the task is running in (release mode, when scanning past build only)
* (Advanced V2 only) Delimiter for the tag separation in the WI Loop, defaults to colon ':'
* (Advanced V2 only) Do not generate release notes of a re-deploy. If this is set, and a re-deploy occurs the task will succeeds with a warning
* (Outputs) Optional: Name of the variable that markdown contents will be copied into for use in other tasks

Using the settings for the output file shown above, the release notes will be created in the specified folder, and will probably need be copied by a task such as 'Copy Files' to your final required location or email using a extension such as the [Send Email](https://marketplace.visualstudio.com/items?itemName=rvo.SendEmailTask) extension


