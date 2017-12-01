### Releases
- 1.0.x - Initial release

### Background

This extension contains tasks that act as a supplement to the ones contained in the [Microsoft provided Azure DevTest Lab Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuredevtestlabs.tasks). 

In the Microsoft extension, they have provided Virtual Machine management tasks including VM Creation and Deletion, but missed out the tasks to Start and Stop VMs. This extension aims to address this omission.  

The tasks in this extension are designed such that they can make uses of the same Azure RM VSTS Endpoint as the Microsoft DevLabs Tasks.

### Included Tasks
The following tasks are in this extension
- **StartVM** - A task to start the named VM
- **StopVM** - A task to stop the named VM

### Parameters for All Tasks
All tasks requires the following inputs:

- **Azure RM Subscription** - Azure Resource Manager subscription to configure before running.
- **Source Lab VM ID** - Resource ID of the source lab VM. The source lab VM must be in the selected lab, as the custom image will be created using its VHD file. You can use any variable such as *$(labVMId)*, the output of calling Create Azure DevTest Labs VM, that contains a value in the form */subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/virtualMachines/{vmName}*.

