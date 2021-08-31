# THIS PROJECT IS NOT UNDER ACTIVE DEVELOPMENT
<hr>

## History

 This PowerShell based extension was designed to run only on Windows based Agents and within Classic Builds. This was because these were the only options when it was originally created. Over time is was enhanced, using my own business logic, to work out associated work items and changesets/commits and to work within Classic Releases.

The use of PowerShell for the extension, and especially my own proprietary templating system, made adding new cross platform features difficult. Hence I decided to build the much enhanced [Node based Release Notes Generator](ttps://github.com/rfennell/vNextBuild/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task) extension.

 - Being Node based it can run on any agent platform
 - Use Handlebars based templates
 - Uses standard Microsoft API calls to work out the associated work items and commits/changeset
 - Support Classic Builds, Classic Releases and MultiStage YAML Pipelines
 - Has support for associated PRs and much much more...

As this PowerShell based extension has had no active development in the last two years, and it is far surpassed in functionality by the Node based version, I am deprecating support for it.
<hr>

# Summary of this Extension
* Written in PowerShell
* Requires a Windows based build/release agents
* Can be used in Azure DevOps Pipeline builds and releases
* Uses custom logic to work out the work items and commits/changesets associated with the build/release

# Usage
[See this original blog post](http://blogs.blackmarble.co.uk/blogs/rfennell/post/2016/03/01/A-vNext-build-task-and-PowerShell-script-to-generate-release-notes-as-part-of-TFS-vNext-build) of more details on this task and its associated PowerShell script it was developed from.

This task is available as [an extension in the VSTS marketplace](https://marketplace.visualstudio.com/items?itemName=richardfennellBM.BM-VSTS-GenerateReleaseNotes-Task)

This task generates a release notes file as part of a VSTS/TFS Build and/or Release pipeline. Most of the samples in this WIKI generate Markdown but it also possible to generate other formats such as HTML with appropriate templates.

The output for a build based report using Markdown might be something like the following:

> Release notes for build SampleSolution.Master
>
> Build Number: 20160229.3
> Build started: 29/02/16 15:47:58
> Source Branch: refs/heads/main
>
> Associated work items
>
> Task 60 [Assigned by: Bill <TYPHOONTFS\Bill>] Design WP8 client
> Associated change sets/commits
>
> ID bf9be94e61f71f87cb068353f58e860b982a2b4b Added a template
> ID 8c3f8f9817606e48f37f8e6d25b5a212230d7a86 Start of the project

## Description of Types of Template
[A range of sample template files can be found here](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates)

The use of a template allows the user to define the layout and fields shown in the release notes document. It is basically a markdown file (or other format of your choice) with tags to denote the fields (the properties on the JSON response objects returned from the VSTS REST API) to be replaced when the tool generates the report file.

The only real change from standard markdown is the use of the @@TAG@@ blocks to denote areas that should be looped over i.e: the points where we get the details of all the work items and commits associated with the build.

### A Basic Build Template
A sample template for a build based report is shown below. It lists the build summary details and core details of each associated changeset/commit and work item.

    # Release notes for build $(Build.DefinitionName)
    **Build Number**  : $($build.buildnumber)
    **Build started** : $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)
    **Source Branch** : $($build.sourceBranch)
    ### Associated work items
    @@WILOOP@@
    * **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')]     $($widetail.fields.'System.Title')
    @@WILOOP@@
    ### Associated change sets/commits
    @@CSLOOP@@
    * **ID $($csdetail.changesetid)$($csdetail.commitid)** $($csdetail.comment)
    @@CSLOOP@@

* Note 1: We can return the builds startTime and/or finishTime, remember if you are running the template within an automated build the build by definition has not finished so the finishTime property is empty to can’t be parsed. This does not stop the generation of the release notes, but an error is logged in the build logs.
* Note 2: We have some special handling in the @@CSLOOP@@ section, we include both the changesetid and the commitid values, only one of there will contain a value, the other is blank. Thus allowing the template to work for both GIT and TFVC builds. Also note if a Git commit is on a remote Git repo (not VSTS or TFS) then the details available are reduced.

This give an output as follows

> #Release notes for build Validate-ReleaseNotesTask.Master
> **Build Number**  : 20160325.12
> **Build started** : 25/03/16 09:07:47
> **Source Branch** : refs/heads/main
> ###Associated work items
> None
> ###Associated change sets/commits
> * **ID 4e9b75b4a9d3b64a5e6abf9975b9ed1a1c29682f** Added a more dump based
> * **ID 3205f570a9866be5b837f88660866741cc404716** Corrected content

### Template that 'dumps' out available values
This version of the template file dumps out all the available fields to help you find all the options open to you.

    # Release notes for build $(Build.DefinitionName)
    $($build)
    ### Associated work items
    @@WILOOP@@
    * $($widetail)
    @@WILOOP@@
    ### Associated change sets/commits
    @@CSLOOP@@
    * $($csdetail)
    @@CSLOOP@@

This give an output as follows

> #Release notes for build Validate-ReleaseNotesTask.Master
> @{_links=; plans=System.Object[]; id=330; buildNumber=20160325.12; status=inProgress; queueTime=2016-03-25T09:07:44.7394253Z; startTime=2016-03-25T09:07:47.6398974Z; url=https://xxx.visualstudio.com/DefaultCollection/670b3a60-2021-47ab-a88b-d76ebd888a2f/_apis/build/Builds/330; definition=; buildNumberRevision=12; project=; uri=vstfs:///Build/Build/330; sourceBranch=refs/heads/main; sourceVersion=4e9b75b4a9d3b64a5e6abf9975b9ed1a1c29682f; queue=; priority=normal; reason=manual; requestedFor=; requestedBy=; lastChangedDate=2016-03-25T09:07:47.317Z; lastChangedBy=; parameters={"system.debug":"false","BuildConfiguration":"release","BuildPlatform":"any cpu"}; orchestrationPlan=; logs=; repository=; keepForever=False}
> ###Associated work items
> None
> ###Associated change sets/commits
> * @{treeId=70442c2d1cec4465105fa7169fa1261d533312b9; push=; commitId=4e9b75b4a9d3b64a5e6abf9975b9ed1a1c29682f; author=; committer=; comment=Added a more dump based; parents=System.Object[]; url=https://xxx.visualstudio.com/DefaultCollection/_apis/git/repositories/bebd0ae2-405d-4c0a-b9c5-36ea94c1bf59/commits/4e9b75b4a9d3b64a5e6abf9975b9ed1a1c29682f; remoteUrl=https://xxx.visualstudio.com/DefaultCollection/GitHub/_git/VSTSBuildTaskValidation/commit/4e9b75b4a9d3b64a5e6abf9975b9ed1a1c29682f; _links=}
> * @{treeId=07a1d5b2ed943500667961e8af6c585d6834d1ae; push=; commitId=3205f570a9866be5b837f88660866741cc404716; author=; committer=; comment=Corrected content; parents=System.Object[]; url=https://xxx.visualstudio.com/DefaultCollection/_apis/git/repositories/bebd0ae2-405d-4c0a-b9c5-36ea94c1bf59/commits/3205f570a9866be5b837f88660866741cc404716; remoteUrl=https://xxx.visualstudio.com/DefaultCollection/GitHub/_git/VSTSBuildTaskValidation/commit/3205f570a9866be5b837f88660866741cc404716; _links=}

### Release Templates
Release templates are identical to a build template with an extra @@BUILDLOOP@@ tag

    # Release notes for release $(Build.DefinitionName)
    **Release Number**  : $($release.name)
    **Release completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$release.modifiedOn)

    **Changes since last successful release to '$stagename'**
    **Including releases:**    $(($releases | select-object -ExpandProperty name) -join ", " )

    ## Builds
    @@BUILDLOOP@@
    ###$($build.definition.name)
    # Release notes for build $defname
    **Build Number**  : $($build.buildnumber)
    **Build started** : $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)
    **Source Branch** : $($build.sourceBranch)
    ###Associated work items
    @@WILOOP@@
    * **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')]     $($widetail.fields.'System.Title')
    @@WILOOP@@
    ### Associated change sets/commits
    @@CSLOOP@@
    * **ID $($csdetail.changesetid)$($csdetail.commitid)** $($csdetail.comment)
    @@CSLOOP@@

    ----------

    @@BUILDLOOP@@

[For sample template files click here](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates)

## How the Template Works
What is done behind the scenes is that each line of the template is evaluated as a line of PowerShell in turn, the in memory versions of the objects are used to provide the runtime values. The available objects to get data from at runtime are

* $release – the release details returned by the REST call Get Release Details (only available for release based usage of the task)
* $releases – all the release details returned by the REST call Get Release Details (only available for release based usage of the task) [see Issues #34](https://github.com/rfennell/vNextBuild/issues/34)
* $build – the build details returned by the REST call Get Build Details. If used within a release, as opposed to a build, this is set to each build within the @@BUILDLOOP@@ block. For build based release notes it is set once. **Note** if you wish to access inner build parameter values [see Issue #55](https://github.com/rfennell/vNextBuild/issues/55)
* $widetail – the details of a given work item inside the loop returned by the REST call Get Work Item (within the @@WILOOP@@@ block)
* $csdetail – the details of a given changeset/commit inside the loop by the REST call to Changes or Commit depending on whether it is a GIT or TFVC based build (within the @@CSLOOP@@@ block)

## Usage on a VSTS build workflow
The build task needs to be built and uploaded as per the standard process detailed in the [Building the tasks in this repo](https://github.com/rfennell/vNextBuild/wiki/Build-Tasks)

Once the tool is upload to your TFS or VSTS server it can be added to a build process.
The task can be used in two ways

### A template file stored in source control
In this form the task takes three parameters

![Inline usage](https://github.com/rfennell/vNextBuild/wiki/ReleaseNotesFile.png)

* The output file name. Recommended to use **$(Build.ArtifactStagingDirectory)\releasenotes.md** for build based usage (so the file ends in the build drops) and to use **$(System.DefaultWorkingDirectory)\releasenotes.md** for release based usage (you need to consider where to send this files in the end, as there is no concept of a release drop location)
* Whether to load the template from a file in source control (the default) or as an inline string parameter
* The template file name, which should point to a file in source control.

### A template file is provided as an inline parameter
In this form the task takes three parameters

![Inline usage](https://github.com/rfennell/vNextBuild/wiki/ReleaseNotesInLine.png)

* The output file name. Recommended to use **$(Build.ArtifactStagingDirectory)\releasenotes.md** for build based usage (so the file ends in the build drops) and to use **$(System.DefaultWorkingDirectory)\releasenotes.md** for release based usage (you need to consider where to send this files in the end, as there is no concept of a release drop location)
* Whether to load the template from a file in source control (the default) or as an inline string parameter
* The template text is entered as text as a parameter in the task.
* (Advanced) Use default credentials - default is false so the build services personal access token is automatically used. If true the credentials of local account the agent is running as are used (only usually used on-prem)
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Generate release notes for only primary release artifact, default is False (release mode only)
* (Advanced) Generate release notes for only trigger release artifact, default is False (release mode only)
* (Advanced) Generate release notes for only the release that contains the task, do not scan past releases, default is True (release mode only)
* (Advanced) Name of the release stage to look for the last successful release in, default to empty value so uses the current stage of the release that the task is running in (release mode, when scanning past build only)
* (Advanced) Maximum number of work items to show in report (default 50)
* (Advanced) Maximum number of changesets/commits to show in report (default 50)
* (Advanced) A boolean flag whether to over-write output file or append to it
* (Advanced) A boolean flag whether to added parent work items of those associated with a build
* (Advanced) A comma-separated list of Work Item types that should be included in the output.
* (Advanced) A comma-separated list of Work Item states that should be included in the output.
* (Advanced) A boolean flag whether when running inside a release the WI/Commit for all builds are returned as a single list as opposed to being listed by builds - not that a different template (see [samples](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates/GenerateReleaseNotes%20(Original%20Powershell%20based)) is required for this to work, one with no **@@BUILDLOOP@@** entry. (In 2.18.x and later)
* (Advanced) A comma-separated list of build tags.
* (Outputs) Optional: Name of the variable that markdown contents will be copied into for use in other tasks

When run you should expect to see a build logs as below and a releases notes file in your drops location.