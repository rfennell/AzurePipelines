# Artifact Description

Tried to get a one line comment for the reason or the build.

- First tries to get the PR reason for the primary Git artifact, this is only available for builds triggered by PRs
- If the PR reason cannot be found checks for the comment on the first commit, assuming this is a merge commit so has a useful message
- if nothing can be found an empty string is returned

This task can be useful if you wish to send a notification as part of your release process e.g. use this task to get the PR reason and then use this text in another task to send a Tweet or Email. 

## Usage

Add the task to a build or release. No further configuration is required.

The PR reason, if available will be set in the task's output parameter.


## Output Parameters
- OutputText - The name of the variable to output the value to, this variable does not to have be pre-created.

