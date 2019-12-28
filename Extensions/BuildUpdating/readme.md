A set of tasks to manage details of builds, it is assumed these tasks will usually be called from a release pipeline.

- V1 - was Windows only
- V2 - are cross platform (released Dec 2019)

## Included Tasks
### Build Retension Task
This task sets the 'keep forever' retension flag on a build. It takes one parameter, the build selection mode, set to either:

* Select only the primary build associated with the release (default)
* All the build artifacts associated with the release
* A comma separated list of build artifacts

As of 1.7.x you also get the option to choose to set or unset the retension to allow rollback scenarios

There is also an advanced option
* (Advanced) Use use build agents default credentials as opposed to agent token - usually only every needed for TFS usage

### Get Build Variable Task
This task gets the value of a specified variable from a build definition, then publishes the value to a local variable from the current build/release.
 * The build definition id must be supplied.
 * The name of the variable to get
 * The local variable which is updated. Note that this is only updated to the scope of the current build or release. Not the definition

### Update Build Variable Task
This task allows a variable to be set in a build definition.

The prime use of this task is envisaged to be the updating of a variable that specifies a version number that needs to be incremented when a release to production occurs.

It uses the following parameters

* Build selection mode
    * Only the primary build associated with the release (default)
    * All the build artifacts associated with the release
    * A comma separated list of build artifacts
* Variable name to update
* Method to update the variable
    * Auto-increment the variable (default)
    * Specify a value
* Value if not set to auto-increment
* (Advanced) Use use build agents default credentials as opposed to agent token - usually only every needed for TFS usage

**Important**: The default rights of a build agent running a release is to not have the permission to edit the build definition (for pipeline variables) or the variable group (for variable group variables). If this task is used without altering these appropriate permission you will get an error from the following list


> Exception calling "UploadString" with "3" argument(s): "The remote server returned an error: (403) Forbidden."
> ##[error]Microsoft.PowerShell.Commands.WriteErrorException: Cannot update the variable group ...
> ##[error]Microsoft.PowerShell.Commands.WriteErrorException: Cannot update the build definition ...

To address this problem you need to grant rights

#### For Pipeline Variables 

Add permission to edit the build definition

1. In a browser select the Pipeline tab
1. Select the folder view
1. Click the ... on the right and select Security
1. Pick the user 
  - 'Project Collection Build Service (_a name_)' [(if your builds are scoped to the project collection)](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/options?view=vsts&tabs=yaml#build-job-authorization-scope)   
  - '(_projectname_) Build Service (_a name_)' [(if your builds are scoped to the project )](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/options?view=vsts&tabs=yaml#build-job-authorization-scope) 

    and make sure they have the 'Edit build definitions' set to allow

#### For Variables Groups 

Notes: Note supported in TFS 2017 due to lack of API calls

Add permission to edit the variable group definition

1. In a browser select the Library tab
1. Edit the required variable group
1. Select the security tab
4. Pick (or add) the user 
  - 'Project Collection Build Service (_a name_)' [(if your builds are scoped to the project collection)](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/options?view=vsts&tabs=yaml#build-job-authorization-scope)   
  - '(_projectname_) Build Service (_a name_)' [(if your builds are scoped to the project )](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/options?view=vsts&tabs=yaml#build-job-authorization-scope) 

    and make sure they have the 'Administrator' right set
5. Save the changes
