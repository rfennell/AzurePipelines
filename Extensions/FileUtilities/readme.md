This set of tasks perform file copy related actions

## File Copy with Filters

This task finds all the files that match a given pattern via a recursive search of the source folder. The selected files are the copied to the single target folder e.g. find all the DACPAC file and place them in the **.\drops\db folder**

This task was developed as a short term fix around the time of TFS 2015.1. In this and earlier versions of vNext build the 'Publish Build Artifacts' searched for files, copied them to the staging folder and then onto the drops location. In later versions these steps are split into two task, one to build the folder structure, the other to move the content. This split functionality is what this task was designed to assist with.

The reason to use still use this task over the built in one is that it flattens folder structures by default. Useful to get all the files of a single type into a single folder.

### Usage

- Source Folder e.g. $(build.sourcesdirectory)
- Target Folder e.g. $(build.artifactstagingdirectory)\$(ArtifactName)\BlackMarble.Victory.Services.DACPackage_Packaged
- File types e.g. *.dacpac
- Filter on e.g. a PowerShell filter

In effect this task wrappers [Get-ChildItem](https://technet.microsoft.com/en-us/library/hh849800.aspx), see this commands online documentation for the filtering options

This tasks would usually be followed by a 'Publish Build Artifacts' task to move the contents to the build drop.

## GetArtifactFromUncShareTask

# IMPORTANT

**THIS TASK CAN ONLY COPY BUILD ARTIFACTS FROM UNC FILESHARE BASED BUILD DROP LOCATIONS.**

You will get an error in the form 

> Cannot access source path [#/475339/atrifact]** if you try to use it with a server build drop

***

With the advent of TFS 2015.2 RC (and the associated VSTS release) we have seen the short term removal of the ‘External TFS Build’ option for the Release Management artifacts source. This causes me a bit of a problem as I wanted to try out the new on premises vNext based Release Management features on 2015.2, but don’t want to place the RC on my production server (though there is go live support). Also the ability to get artifacts from an on premises TFS instance when using VSTS open up a number of scenarios, something I know some of my clients had been investigating.

To get around this blocker I have written a vNext build task that does the getting of a build artifact from the UNC drop. It supports both XAML and vNext builds. Thus replacing the built in artifact linking features.

## Usage
To use the new task:

- Get the task from my vNextBuild repo (build using the instructions on the repo’s wiki) and install it on your TFS 2015.2 instance (also use the notes on the repo’s wiki). 
- In your build, disable the auto getting of the artifacts for the environment (though in some scenarios you might choose to use both the built in linking and my custom task)
- Add the new task to your environment’s release process, the parameters are 
    - TFS Uri – the Uri of the TFS server inc. The TPC name 
    - Team Project – the project containing the source build 
    - Build Definition name – name of the build (can be XAML or vNext) 
    - Artifact name – the name of the build artifact (seems to be ‘drop’ if a XAML build) 
    - Build Number – default is to get the latest successful completed build, but you can pass a specific build number 
    - Username/Password – if you don’t want to use default credentials (the user the build agent is running as), these are the ones used. These are passed as ‘basic auth’ so can be used against an on prem TFS (if basic auth is enabled in IIS)  or VSTS (with alternate credentials enabled).

When the task runs it should drop artifacts in the same location as the standard mechanism, so can be picked up by any other tasks on the release pipeline using a path similar to **$(System.DefaultWorkingDirectory)\buildname\drop**

## Limitations
The task in its current form does not provide any linking of artifacts to the build reports, or allow the selection of build versions when the release is created. This removing audit trail features.

However, it does provide a means to get a pair of TFS servers working together, so can certainly enable some R&D scenarios while we await 2015.2 to RTM and/or the ‘official’ linking of External TFS builds as artifact

## Update XML file

This task edits the value if an attribute in a XML file based on a XPath filter

The prime use for this is to set environment specific value in web.config or app.config files

### Usage

- Filename e.g. $(SYSTEM.ARTIFACTSDIRECTORY)/myfile.dll.config [can include wildcards $(SYSTEM.ARTIFACTSDIRECTORY)/*.config]
- XPath e.g. /configuration/appSettings/add[@key='A variable']
- Attribute e.g. value [optional: if left blank the InnerText on the selected node will be updated]
- Value e.g. 'the new value'
- Recurse e.g. True (whether any wildcards in the filename should be searched for recursivally)
