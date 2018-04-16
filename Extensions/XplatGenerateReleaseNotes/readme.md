This task generates a release notes file based on a template passed into the tool.  The data source for the generated Release Notes is the VSTS REST API's comparison calls that are also used by the VSTS UI to show the associated Work items and commit/changesets between two releases. Hence this task should generate the same list of items as the VSTS UI.

Note: That this comparison is only done against the primary build artifact linked to the Release

If the template file is markdown the output report being something like the following:

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

> There are differences in the template syntax between Version 1 and Version 2 of this task.  These differences are due to Rest API changes between VSTS and TFS.

The use of a template allows the user to define the format, layout and fields shown in the release notes document. It is basically a file in the format required with tags to denote the fields to be replaced when the tool generates the report file.

- Most samples are in Markdown, but samples are available for HTML
- The @@VALUE@@ tags are special loop control flags
- The ${properties} are the fields to be expanded from properties in the JSON response objects returned from the VSTS REST API

The only real change from standard markdown is the use of the @@TAG@@ blocks to denote areas that should be looped over i.e: the points where we get the details of all the work items and commits associated with the build.

**Version 1.x**
```
# Release notes
## Notes for release  ${releaseDetails.releaseDefinition.name}
**Release Number**  : ${releaseDetails.name}
**Release completed** : ${releaseDetails.modifiedOn}
**Compared Release Number**  : ${compareReleaseDetails.name}

### Associated work items
@@WILOOP@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP@@

### Associated commits
@@CSLOOP@@
* **ID ${csdetail.commitId} ** ${csdetail.comment}
@@CSLOOP@@
```

**Version 2.x**

```
# Release notes
## Notes for release  ${releaseDetails.releaseDefinition.name}
**Release Number**  : ${releaseDetails.name}
**Release completed** : ${releaseDetails.modifiedOn}
**Compared Release Number**  : ${compareReleaseDetails.name}

### Associated work items
@@WILOOP@@
* ** ${widetail.fields['System.WorkItemType']} ${widetail.id} ** Assigned by: ${widetail.fields['System.AssignedTo']}  ${widetail.fields['System.Title']}
@@WILOOP@@

### Associated commits
@@CSLOOP@@
* **ID ${csdetail.id} ** ${csdetail.message}
@@CSLOOP@@
```

You can see the full contracts of what you can access by looking here:

- [WorkItems](https://docs.microsoft.com/en-gb/rest/api/vsts/wit/work%20items/get%20work%20item#workitem)
- [Commits](https://docs.microsoft.com/en-gb/rest/api/vsts/build/builds/get%20build%20changes#change)

> Please note that git commits are automatically expanded by the task (TFS/VSTS will truncate to 100 chars).

What is done behind the scenes is that each line of the template is evaluated as a line of Node.JS in turn, the in memory versions of the objects are used to provide the runtime values. The available objects to get data from at runtime are

* releaseDetails – the release details returned by the REST call Get Release Details of the release that the task was triggered for.
* compareReleaseDetails - the release that the REST call is using to comapre against
* widetail – the details of a given work item inside the loop returned by the REST call Get Work Item (within the @@WILOOP@@@ block)
* csdetail – the details of a given changeset/commit inside the loop by the REST call to Changes or Commit depending on whether it is a GIT or TFVC based build (within the @@CSLOOP@@@ block)

There are sample templates that just produce basic releases notes and dumps out all the available fields (to help you find all the available options) for both builds and releases

- [Sample templates for version 1](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates/Version_1) 
- [Sample templates for version 2](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates/Version_2) 

## Usage
Once the extension is added to your TFS or VSTS server, the task should be available in the utilities section of 'add tasks'

The task takes three parameters

* The output file name, for builds this will normally be set to $(Build.ArtifactStagingDirectory)\releasenotes.md as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like $(System.DefaultWorkingDirectory)\releasenotes.md. Where you choose to send the created files is down to your deployment needs.
* A picker allows you to set if the template is provided as a file in source control (usually used for builds) or an inline file (usually used for release management). The setting of this picker effects which third parameter is shown
* Either - The template file name, which should point to a file in source control.
* Or - The template text.
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Name of the release stage to look for the last successful release in, default to empty value so uses the current stage of the release that the task is running in (release mode, when scanning past build only)
* (Outputs) Optional: Name of the variable that markdown contents will be copied into for use in other tasks

Using the settings for the output file shown above, the release notes will be created in the specified folder, and will probably need be copied by a task such as 'Publish Artifacts' to your final required location.

## Changes
- 1.0 - Initial release
- 1.1 - Reduced the API version requirement to allow support for TFS 2017 as well as VSTS (still using preview API)
- 1.2 - Includes PR130 @gregpakes that added multiple artifact support, moved to async/await model
- 1.3 - Includes PR141 @gregpakes that address issues with errors being swallowed and no work items being listed
- 1.4 - Includes PR157 @gregpakes that address issues with redeployments
- 1.5 - Issue200 Engineering fixes for build process, also fixes an issue if empty work item list is returned when checking between releases
- 1.6 - Issue215 Fixed error when release references build that that is not VSTS repo based
- 1.7 - Issue270 Fixed problem getting work item detail on TFVC repos
- 1.8 - Issue272 Fixed problem with no output if the artifact source is not a VSTS hosted repository
- 1.9 - Issue277 fixed vulnerability in Moment 2.19.1 NPM package, no functional change
- 2.0 - Major refactor PR305 by @gregpakes to move to newer API, does contain breaking changes to template. Hence from this point both V1 and V2 will be shipped in the same extension
