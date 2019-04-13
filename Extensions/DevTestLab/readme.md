# Background

This extension contains tasks that act as a supplement to the ones contained in the [Microsoft provided Azure DevTest Lab Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuredevtestlabs.tasks).

In the Microsoft extension, they have provided Virtual Machine management tasks including VM Creation and Deletion, but missed out the tasks to Start and Stop VMs. This extension aims to address this omission.

The tasks in this extension are designed such that they can make uses of the same Azure RM VSTS Endpoint as the Microsoft DevLabs Tasks.

# Included Tasks
The following tasks are in this extension
- **StartVM** - A task to start the named VM
- **StopVM** - A task to stop the named VM

# Parameters for All Tasks
All tasks requires the following inputs:

- **Azure RM Subscription** - Azure Resource Manager subscription to configure before running.
- **Source Lab VM ID** - Resource ID of the source lab VM. The source lab VM must be in the selected lab, as the custom image will be created using its VHD file. You can use any variable such as *$(labVMId)*, the output of calling Create Azure DevTest Labs VM, that contains a value in the form.
`/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/virtualMachines/{vmName}`
   - {subId} can be found in http://portal.azure.com on the DevTest Lab Overview as the 'Subscription ID'
   - {labName} can be found in http://portal.azure.com on the DevTest Lab Overview as the 'Resource group;
   - {vmName} can be found in http://portal.azure.com on the DevTest Lab in the 'My virtual machines' table in the name column

e.g.

`/subscriptions/**48b5a96e-e215-4db3-a0a9-8aba2c333333**/resourceGroups/**DevLabRG143333**/providers/Microsoft.DevTestLab/labs/MVP-DevLab/virtualMachines/**devlab-agent1**`

### Note

A strange effect is that of you get the wrong value such as that you use ones for the VMs and not the Environment, it is possible the start task works but the stop tasks fails.