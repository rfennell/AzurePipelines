## Changes
- 1.0 - Initial release
- 1.1 - Bug fix, issue with REST call made to return build details
- 1.2 - Bug fix, UTF8 encoding issue
- 1.3 - Added support for Release Management
        Added support for inline definition of template 
- 1.4 - Add advanced option to choose if PAT or defaultcreds are used
- 1.5 - Put in logic to skip any non VSTS release artifacts
- 1.6 - Added parameter to limit release notes generation in a release to only primary artifact 
- 2.0 - Added support to look back to through prior releases to last successful deployment
- 2.1 - Made the text that is shown when there is no WI or Changeset/Commit
- 2.2 - PR from @gregpakes - Made generate markdown available as output variablefrom 
- 2.3 - PR from @yermax - Fixed bug that defaultcreds not being passed to all functions
        Fixed bug that only first line of generate markdown available in output variable
- 2.4 - Added extra error traps to handle lookups on deleted builds
- 2.5 - Improved error tapping on render method
- 2.6 - Altered logging to remove items that should not be warning
- 2.7 - Included PR from @Beej126 hide changeset with no comment and @gregpakes added newlines to output variable string
- 2.8 - Fixed for Issues #109, fixed build detection logic
- 2.9 - PR from @paulxb Fixed a bug with $defname and $stagename not populating 
- 2.10 - PR from @uioporqwerty #134 to fix issue with TFS2015.2 adn releases
- 2.11 - Issue195 Added override in advanced settings to more than 50 wi or changesets/commits can be returned
- 2.12 - PR221 SWarnberg - Show parent work items of those directly associated with build
         Added option to append to output file as opposed to just overwriting
- 2.13 - Improved the error message when tempalte does not render - now shows failing line
- 2.14 - Issue244 fix for "Append Output File" option fails with 'The term 'Addt-Content' is not recognized' error
- 2.15 - Issue242 fix for handling JSON data over 2Mb in size

This task generates a release notes file based on a template passed into the tool.  The data source for the generated Release Notes is the VSTS REST API's:
- if used in a build it is the current active build
- if it is used in a release, then all the release artifacts are scanned back to the last successful release to the current environment and work items and commits/changesets retrieved for all these build artifcats. This is different mechanisim to that used by the VSTS UI to show the associated Work items and commit/changesets between two releases. Hence this task may not generate the same list of items as the VSTS UI. 


If the template file is markdown the output report being something like the following:

> Release notes for build SampleSolution.Master
> 
> Build Number: 20160229.3
> Build started: 29/02/16 15:47:58
> Source Branch: refs/heads/master
> 
> Associated work items
> 
> Task 60 [Assigned by: Bill <MYDOMAIN\Bill>] Design WP8 client
> Associated change sets/commits
> 
> ID bf9be94e61f71f87cb068353f58e860b982a2b4b Added a template
> ID 8c3f8f9817606e48f37f8e6d25b5a212230d7a86 Start of the project

## The Template
The use of a template allows the user to define the format, layout and fields shown in the release notes document. It is basically a file in the format required with tags to denote the fields to be replaced when the tool generates the report file.

- Most samples are in Markdown, but samples are available for HTML
- The @@VALUE@@ tags are special loop control flags
- The $(properties) are the fields to be expanded from properties in the JSON response objects returned from the VSTS REST API 

The only real change from standard markdown is the use of the @@TAG@@ blocks to denote areas that should be looped over i.e: the points where we get the details of all the work items and commits associated with the build.

    #Release notes for build $defname  
    **Build Number**  : $($build.buildnumber)    
    **Build started** : $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)     
    **Source Branch** : $($build.sourceBranch)  
    ###Associated work items  
    @@WILOOP@@  
    * **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')]     $($widetail.fields.'System.Title') 
    @@WILOOP@@  
    ###Associated change sets/commits  
    @@CSLOOP@@  
    * **ID $($csdetail.changesetid)$($csdetail.commitid)** $($csdetail.comment)    
    @@CSLOOP@@   

* Note 1: We can return the builds startTime and/or finishTime, remember if you are running the template within an automated build the build by definition has not finished so the finishTime property is empty to can’t be parsed. This does not stop the generation of the release notes, but an error is logged in the build logs.
* Note 2: We have some special handling in the @@CSLOOP@@ section, we include both the changesetid and the commitid values, only one of there will contain a value, the other is blank. Thus allowing the template to work for both GIT and TFVC builds.

What is done behind the scenes is that each line of the template is evaluated as a line of PowerShell in turn, the in memory versions of the objects are used to provide the runtime values. The available objects to get data from at runtime are

* $release – the release details returned by the REST call Get Release Details of the release that the task was triggered for (only available for release based usage of the task)
* $releases – all the release details returned by the REST call Get Release Details (only available for release based usage of the task)
* $build – the build details returned by the REST call Get Build Details. If used within a release, as opposed to a build, this is set to each build within the @@BUILDLOOP@@ block. For build based release notes it is set once.
* $widetail – the details of a given work item inside the loop returned by the REST call Get Work Item (within the @@WILOOP@@@ block)
* $csdetail – the details of a given changeset/commit inside the loop by the REST call to Changes or Commit depending on whether it is a GIT or TFVC based build (within the @@CSLOOP@@@ block)

There are [sample templates](https://github.com/rfennell/vNextBuild/tree/master/SampleTemplates) that just produce basic releases notes and dumps out all the available fields (to help you find all the available options) for both builds and releases  

## Usage
Once the extension is added to your TFS or VSTS server, the task should be available in the utilities section of 'add tasks'

The task takes three parameters

* The output file name, for builds this will normally be set to $(Build.ArtifactStagingDirectory)\releasenotes.md as the release notes will usually be part of your build artifacts. For release management usage the parameter should be set to something like $(System.DefaultWorkingDirectory)\releasenotes.md. Where you choose to send the created files is down to your deployment needs. 
* A picker allows you to set if the template is provided as a file in source control (usually used for builds) or an inline file (usually used for release management). The setting of this picker effects which third parameter is shown
* Either - The template file name, which should point to a file in source control.
* Or - The template text.
* (Advanced) Use default credentials - default is false so the build services personal access token is automatically used. If true the credentials of local account the agent is running as are used (only usually used on-prem)
* (Advanced) Empty set text - the text to place in the results file if there is no changeset/commit or WI content
* (Advanced) Generate release notes for only primary release artifact, default is False (release mode only)
* (Advanced) Generate release notes for only the release that contains the task, do not scan past releases, default is True (release mode only)
* (Advanced) Name of the release stage to look for the last successful release in, default to empty value so uses the current stage of the release that the task is running in (release mode, when scanning past build only)
* (Advanced) A boolean flag whether to over-write output file or append to it
* (Advanced) A boolean flag whether to added parent work items of those associated with a build
* (Advanced) A comma-separated list of Work Item types that should be included in the output.
* (Advanced) A comma-separated list of Work Item states that should be included in the output.
* (Outputs) Optional: Name of the variable that markdown contents will be copied into for use in other tasks

Using the settings for the output file shown above, the release notes will be created in the specified folder, and will probably need be copied by a task such as 'Publish Artifacts' to your final required location.
