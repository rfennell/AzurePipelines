# Release Notes for {{buildDetails.buildNumber}}
|||
|-|-|
|**Release**| {{buildDetails.buildNumber}}|
|**Branch**| {{buildDetails.sourceBranch}}|
|**Environment**| {{currentStage.name}}|
|**Tags**| {{buildDetails.tags}}|
|**Date**| {{buildDetails.startTime}}|

# Included Packages
{{#forEach consumedArtifacts}}
## {{this.versionName}} ({{this.artifactCategory}})
### Commits
| SHA | Message |
|-|-|
{{#forEach this.commits}}
| {{truncate this.id 7}} | {{ this.message}} |
{{/forEach}}

### Work Items
| ID | Message |
|-|-|
{{#forEach this.workitems}}
| {{this.id}} | {{lookup this.fields 'System.Title'}}  |
{{/forEach}}

{{/forEach}}

