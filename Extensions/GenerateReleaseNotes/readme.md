This task generates a markdown release notes file based on a template passed into the tool. The output report being something like the following:

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
The use of a template allows the user to define the layout and fields shown in the release notes document. It is basically a markdown file with tags to denote the fields (the properties on the JSON response objects returned from the VSTS REST API) to be replaced when the tool generates the report file.

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

* $build – the build details returned by the REST call Get Build Details
* $workItems – the list of work items associated with the build returned by the REST call Build Work Items
* $widetail – the details of a given work item inside the loop returned by the REST call Get Work Item
* $changesets – the list of changeset/commit associated with the build build returned by the REST call Build Changes
* $csdetail – the details of a given changeset/commit inside the loop by the REST call to Changes or Commit depending on whether it is a GIT or TFVC based build

There is a [templatedump.md file in my in the PowerShell Scripts repo](https://github.com/rfennell/VSTSPowershell/blob/master/REST/templatedump.md) that just dumps out all the available fields  to help you find all the available options
## Usage
Once the extension is added to your TFS or VSTS server, the task should be available in the utilities section of 'add tasks'

The task takes two parameters

* The output file name which defaults to $(Build.ArtifactStagingDirectory)\releasenotes.md
* The template file name, which should point to a file in source control.
There is no need to pass credentials, this is done automatically

Using the settings for the output file shown above, the release notes will be created in the staging folder, and will hence be copied by the 'Publish Artifacts' task
