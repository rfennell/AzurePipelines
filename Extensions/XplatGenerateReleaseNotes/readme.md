# Summary
Generates release notes for a build or release. the file can be a format of your choice
* Can be used on any type of Azure DevOps Agents (Windows, Mac or Linux)
* For releases, uses same logic as Azure DevOps Release UI to work out the work items and commits/changesets associated with the release
* 2.17.x onwards supports operation in a build whether YAML or legacy, getting the commits/changesets associated with the build. 
* 2.0.x onwards supports tag filtering in the work items listed in a report. A report can have many WILOOPs with different filters. 2.18.x & 2.19.x add support for advanced work item filtering
* The Azure DevOps REST APIs have a limitation that by default they only return 200 items. As a release could include more Work Items or ChangeSets/Commits. A workaround for this has been added [#349](https://github.com/rfennell/AzurePipelines/issues/349). Since version 2.12.x this feature has been defaulted on. To disable it set the variable `ReleaseNotes.Fix349` to `false`

**IMPORTANT** - There have been two major versions of this extension, this is because
* V1 which used the preview APIs and is required if using TFS 2018 as this only has older APIs. This version is not longer shipped in extension download from [GitHub](https://github.com/rfennell/AzurePipelines/releases/tag/XPlat-2.6.9)
* V2 was a complete rewrite by [@gregpakes](https://github.com/gregpakes) using the Node Azure DevOps SDK, with minor but breaking changes in the template format and that oAuth needs enabling on the agent running the tasks .

# Usage
As with my original [PowerShell based Release Notes task](https://github.com/rfennell/vNextBuild/wiki/GenerateReleaseNotes--Tasks), this task generates a release notes file based on a template passed into the tool.  

In the case of a Release, the data source for the generated Release Notes is the Azure DevOps REST API's comparison calls that are also used by the Azure DevOps UI to show the associated Work items and commit/changesets between two releases. Hence this task should generate the same list of items as the Azure DevOps UI.

**Note:** That this comparison is only done against the primary build artifact linked to the Release

If used in the build the release notes are based on the current build only.

If the template file is markdown (other formats are possible) the output report being something like the following:

```
# Release notes
## Notes for release  New Empty Definition 25-Mar
**Release Number** : Release-5
**Release completed** : 2017-04-03T19:32:25.76Z
**Compared Release Number** : Release-4

### Associated work items
* ** Epic 21 ** Assigned by: Richard Fennell (Work MSA) <bm-richard.fennell@outlook.com>  Add items

### Associated commits
* **ID f5f964fe5ab27b1b312f6aa45ea1c5898d74358a ** Updated Readme.md #21
```

## The Template

There are [sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) that just produce basic releases notes for both Git and TFVC based releases for both V1 and V2 formats. Most samples are in Markdown, but it is possible to generate any other format such as HTML

The use of a template allows the user to define the format, layout and fields shown in the release notes document. It is basically a file, in the output format required, with `@@...@@` markers to denote the fields to be replaced when the tool generates the report file.

The `@@..@@` markers are special loop control flags, they should be used in pairs before and after the block to be looped over

The `@@..@@` marker options are as follow

   - `@@CSLOOP@@` should wrapper the block to be performed for all changesets/commits. This marker can accept a regex based filter to be applied to the commit message.
      - `@@CSLOOP[^Merged PR #.+]@@` match only commits/changesets with a commit message in the form 'Merged PR #1234' 
   - `@@WILOOP@@` should wrapper the block to be performed for all work items. This marker can accept a list of tags and field options that can be used as a filter on the work items. The general format is `@@WILOOP[ALL|ANY]:TAG:Fieldname=value:...@@`, there can be any number of parameters e.g.
      - `@@WILOOP:TAG1:TAG2@@` matches work items that have all tags (legacy behaviour for backwards compatability)
      - `@@WILOOP[ALL]:TAG1:TAG2@@` matches work items that have all tags (equivalent to legacy behaviour)
      - `@@WILOOP[ANY]:TAG1:TAG2@@` matches work items that have any of the tags 
      - `@@WILOOP[ALL]:TAG1:System.Title=Exact match to title@@` matches work items that have both the named tag and the field  
      - `@@WILOOP[ANY]:TAG1:System.Title=Exact match to title@@` matches work items that have either the named tag or the field  
      - `@@WILOOP[ANY]:TAG1:Custom.Field=*@@` matches any work items that has a field called Custom.Field irrespective of the value in the field  (matches against the `anyFieldContent` value as a wildcard symbol)
- The `${properties}` blocks inside the `@@..@@` markers are the fields to be expanded from properties in the JSON response objects returned from the Azure DevOps REST API. 

**Note:** To dump all possible values use the form `${JSON.stringify(propertyToDump)}`

**Note:** This task differed from the older [PowerShell based Release Notes task](https://github.com/rfennell/vNextBuild/wiki/GenerateReleaseNotes--Tasks) that used the format `$(properties)`, this task uses the format `${properties}` due to the move from PowerShell to Node within the task

An example template to run within a Release for GIT or TFVC Azure DevOps build based artifacts could be

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

### Associated work items that have both the tags 'Tag 1' and 'Tag2', the legacy default format
@@WILOOP:Tag 1:Tag2@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP:Tag 1:Tag2@@

### Associated work items that have both the tags 'Tag 1' and 'Tag2', the new loop format
@@WILOOP[ALL]:Tag 1:Tag2@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP[ALL]:Tag 1:Tag2@@

### Associated work items that have any of the tags 'Tag 1' or 'Tag2', the new loop format
@@WILOOP[ANY]:Tag 1:Tag2@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP[ANY]:Tag 1:Tag2@@

### Associated work items that have the title 'This is a title' or the tag 'Tage'
@@WILOOP[ALL]:System.Title=This is a title:TAG 1@@  
* **${widetail.fields['System.WorkItemType']} ${widetail.id}** ${widetail.fields['System.Title']}  
@@WILOOP:TAG 1@@  

### Associated commits
@@CSLOOP@@
* **ID ${csdetail.id} ** ${csdetail.message}
@@CSLOOP@@

### Associated commits with regex filter in form 'Merged PR #1234'
@@CSLOOP[^Merged PR #.+]@@
* **ID ${csdetail.id} ** ${csdetail.message}
@@CSLOOP[^Merged PR  #.+]@@

```

## Template Objects ##

What is done behind the scenes is that each `${properties}` block in the template is evaluated as a line of Node.JS in turn. The property  objects available to get data from at runtime are:

### Common objects ###
* **widetail** – the details of a given work item within the `@@WILOOP@@@` block.
* **csdetail** – the details of a given Git commit or TFVC changeset inside the `@@CSLOOP@@@` block

### Release objects (only available in a release) ###
* **releaseDetails** – the release details of the release that the task was triggered for.
* **compareReleaseDetails** - the the previous successful release that comparisons are bein made against

### Build objects (only available in a build) ###
* **buildDetails** – the build details of the build that the task was triggered from.

## Usage
Once the extension is added to your Azure DevOps Server (TFS) or Azure DevOps Services, the task should be available in the utilities section of 'add tasks'

**IMPORTANT** - The V2 Tasks requires that oAuth access is enabled on agent running the task

The task takes the following parameters

* The output file name, for builds this will normally be set to `$(Build.ArtifactStagingDirectory)\releasenotes.md` as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like `$(System.DefaultWorkingDirectory)\releasenotes.md`. Where you choose to send the created files is down to your deployment needs.
* A picker allows you to set if the template is provided as a file in source control or an inline file. The setting of this picker effects which other parameters are shown
    * Either, the template file name, which should point to a file in source control.
    * Or, the template text.
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Name of the release stage to look for the last successful release in, defaults to empty value so uses the current stage of the release that the task is running in.
* (Advanced V2 only) Delimiter for the tag separation in the WI Loop, defaults to colon ':'
* (Advanced V2 only) Equality symbol for the equivalents in field filters in the WI Loop, defaults to equals '='
* (Advanced V2 only) anyFieldContent symbol to represent any value when match field in the WI Loop, defaults to equals '*'
* (Advanced V2 only) Do not generate release notes of a re-deploy. If this is set, and a re-deploy occurs the task will succeeds with a warning
* (Advanced V2 only) Primary Only. If this is set only WI and CS associated with primary artifact are listed, default is false so all artifacts scanned.
* (Outputs) Optional: Name of the variable that release notes contents will be copied into for use in other tasks. As an output variable equates to an environment variable, so there is a limit on the maximum size. For larger release notes it is best to save the file locally as opposed to using an output variable.

### Output location ###

When using this task within a build then it is sensible to place the release notes files as a build artifacts.

However, within a release there are no such artifacts location. Hence, it is recommended that a task such as the [WIKI Updater](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-WIKIUpdater-Tasks) is used to upload the resultant file to a WIKI. Though there are other options such as store the file on a UNC share, in an Azure DevOps Artifact or sent as an email.


