##Typemock Task##
Typemock Isolator provides a way to ‘mock the un-mockable’, such as sealed private classes in .NET, so can be a invaluable tool in unit testing. To allow this mocking Isolator interception has to be started before any unit tests are run and stopped when completed. For a developer this is done automatically within the Visual Studio IDE, but on build systems you have to run something to do this as part of your build process. Typemock provide documentation and tools for common build systems such as MSBuild, Jenkins, Team City and TFS XAML builds. However, they don’t currently provide tools for getting it working with VSTS/TFS vNext build. 

To get around this limitation this task wrappers Tmockrunner.exe, provided by Typemock, which handles the starting and stopping of mocking whilst calling any EXE of your choice.

###Requirements
The following are required to make use of this task
- Typemock Isolator must be installed on the build agent VM 
- This means you need administrative access to the VM. THIS MEANS THIS TASK CANNOT BE USED WITH HOSTED AGENT, you must be using a private build agent

###Setup
This task takes all the same argument as the standard VSTest build task (as it will normally be used as direct replacement for the VSTest task), with the addition of the following parameters used to license TYpemock Isolator

- The company the instance of Typemock is licensed to
- The licensed key
- The path to the Typemock autodeployment folder in source control (usually 'C:\Program Files (x86)\Typemock\Isolator\<version>\AutoDeploy')

Once this configured this task should be able to enable and disable Typemock Isolator before and after any tests are run

Typemock provide documentation on the general use Isolator in build systems in their [online documentation](http://www.typemock.com/docs?book=Isolator&page=Documentation%2FHtmlDocs%2Fintegratingwiththeserver.htm) 
