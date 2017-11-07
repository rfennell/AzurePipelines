Releases

- 1.0 Initial internal release
- 2.0 Public release
- 2.1 Added replacing InnerText of XML nodes as well as attributes in XML task
    - Added support for multi-files on XML task
- 2.2 Made the location of the local copy of the artifact configurable
- 2.3 Issue147 fixed filter for successful builds on UNC copy task
- 3.0 Converted the XML Task to Node.JS from PowerShell to make it cross platform Issue74


This set of tasks perform file copy related actions

## File Copy with Filters

This task finds all the files that match a given pattern via a recursive search of the source folder. The selected files are the copied to the single target folder e.g. find all the DACPAC file and place them in the **.\drops\db folder**

This task was developed as a short term fix around the time of TFS 2015.1. In this and earlier versions of vNext build the 'Publish Build Artifacts' searched for files, copied them to the staging folder and then onto the drops location. In later versions these steps are split into two task, one to build the folder structure, the other to move the content. This split functionality is what this task was designed to assist with.

The reason to use still use this task over the built in one is that it flattens folder structures by default. Useful to get all the files of a single type into a single folder.

###Usage

- Source Folder e.g. $(build.sourcesdirectory)
- Target Folder e.g. $(build.artifactstagingdirectory)\$(ArtifactName)\BlackMarble.Victory.Services.DACPackage_Packaged
- File types e.g. *.dacpac
- Filter on e.g. a PowerShell filter

In effect this task wrappers [Get-ChildItem](https://technet.microsoft.com/en-us/library/hh849800.aspx), see this commands online documentation for the filtering options

This tasks would usually be followed by a 'Publish Build Artifacts' task to move the contents to the build drop.

## GetArtifactFromUncShareTask

With TFS 2015.2 (and the associated VSTS version) Release Management cannot pick-up build artifacts from a remote TFS server.

To get around this hopefully short term blocker this task does the getting of a build artifact from the UNC drop. It supports both XAML and vNext builds. Thus replacing the built in artifact linking feature if Release Management.

It is hoped that at some point in the future there will be a build in way to achieve the linking to remote TFS servers build into VSTS/TFS, thus removing the need for the task.

###Usage

To use the new task

- Install the task in your VSTS or TFS 2015.2 instance.
- In your release definition, disable the auto getting of the artifacts for the environment this is on the environments general tab.

**Note**: In some scenarios you might choose to use both the built in linking to artifacts and this custom task

- Add the new task to your environment’s release process, the parameters are
	- TFS Uri – the Uri of the TFS server inc. The TPC name
	- Team Project – the project containing the source build
	- Build Definition name – name of the build (can be XAML or vNext)
	- Artifact name – the name of the build artifact (seems to be ‘drop’ if a XAML build)
	- Build Number – default is to get the latest successful completed build, but you can pass a specific build number
	- Username/Password – if you don’t want to use default credentials (the user the build agent is running as), these are the ones used. These are passed as ‘basic auth’ so can be used against an on prem TFS (if basic auth is enabled in IIS)  or VSTS (with alternate credentials enabled).

When the task runs it should drop artifacts in the same location as the standard mechanism, so can be picked up by any other tasks on the release pipeline using a path similar to **$(System.DefaultWorkingDirectory)\SABS.Master.CI\drop**

###Limitations

- The agent running the task will almost certainly be hosted on your network as it will need to be able to resolve the address the TFS server to copy artifacts from. This is unlikely to be possible for the Microsoft hosted build agent.
- The task in its current form does not provide any linking of artifacts to the build reports, or allow the selection of build versions when the release is created. Thus removing audit trail features of TFS vNext Release Management.

Even given these limitations, it does provide a means to get a pair of TFS servers working together, so can certainly enable some more edge case scenarios

## Update XML file

This task edits the value if an attribute in a XML file based on a XPath filter

The prime use for this is to set environment specific value in web.config or app.config files

###Usage

- Filename e.g. $(SYSTEM.ARTIFACTSDIRECTORY)/myfile.dll.config [can include wildcards $(SYSTEM.ARTIFACTSDIRECTORY)/*.config]
- XPath e.g. /configuration/appSettings/add[@key='A variable']
- Attribute e.g. value [optional: if left blank the InnerText on the selected node will be updated]
- Value e.g. 'the new value'
- Recurse e.g. True (whether any wildcards in the filename should be searched for recursivally)
