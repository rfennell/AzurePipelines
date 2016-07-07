### Releases
- 1.0.x - Initial release

A set of tasks to manage builds, these tasks be called from a release pipeline.

## Included Tasks
### Build Retension Task
This task sets the 'keep forever' retension flag on a build. It takes one parameter, the build selection mode 

* Select only the primary build associated with the release (default)
* All the build artifacts associated with the release

### Update Build Variable Task
This task allows a variable to be set in a build definition. 

The prime use of this task is envisaged to be the updating of a variable that specificies a version number that needs to be incremented when a release occurs.

It uses the following parameters

* Build selection 
    * Only the primary build associated with the release (default)
    * All the build artifacts associated with the release
* Variable name to update
* Method to update the variable
    * Auto increment the variable (default)
    * Specify a value
* Value if needed
