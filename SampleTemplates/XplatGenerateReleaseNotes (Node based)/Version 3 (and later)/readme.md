# Sample Handlebar Templates and Custom Handlebars Extensions
This folder contains sample Handlebar Templates and custom Handlebars extensions for my [Cross Platform Release Notes Azure DevOps Task](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task)

## What format are the samples?
### Templates
Most of the samples are provided as .MD templates.

> If you wish to output a different format alter the file extension and tags appropriately

They provide basic reports outputted as markdown, showing the common objects available in the task

### Custom Extensions
The extensions are small blocks of Javascript that are injected into the Handlebars processor to perform special functions.

They can be injected either by:
- Injection as inline YAML content using the `customHandlebarsExtensionCode` parameter
- Loaded from a file using the `customHandlebarsExtensionFile` parameter

> In this folder each sample .JS file contains a single custom module, usually with a usage sample. If you wish to use multiple custom modules they can be combined into a single block/file using a `,` as a separator between functions e.g.

```
const handlebars = require("handlebars");
module.exports = {
    count_workitems_by_type: function (array, typeName) {
        return array.filter(wi => wi.fields['System.WorkItemType'] === typeName).length;
    },
    replace_text: function (msg, match, replacement) {
        return msg.replace(match, replacement);
    }
};
```

It is possible that your extension might require the loading of other JavaScript modules, in the above sample the `handlebars` module is needed. Any requested modules need to be loaded from the same folder as the custom Javascript is being run from. The Release Notes task does not automatically handle loading of these modules. So, the best option is to call `npm install` prior to the Release Noes task to make sure the required modules are present in the folder the custom extension is loaded from e.g:

```
- task: Npm@1
  inputs:
    command: 'custom'
    workingDir: '$(System.DefaultWorkingDirectory)'
    customCommand: 'install handlebars'

- task: XplatGenerateReleaseNotes@3
  inputs:
    outputfile: '$(Build.ArtifactStagingDirectory)/releasenotes.md'
    templateLocation: 'File'
    templatefile: '$(System.DefaultWorkingDirectory)/template.hbs'
    customHandlebarsExtensionFile: 'custom.js'
    customHandlebarsExtensionFolder: '$(System.DefaultWorkingDirectory)'
```


## What Samples Are Provided?

### Templates
- [build-handlebars-template.md](build-handlebars-template.md) - a very simple template for build
- [release-handlebars-template.md](release-handlebars-template.md) - a very simple template for a classic Release
- [release-handlebars-dump-template.md](release-handlebars-dump-template.md) - a template to use with Classic Releases to dump the contents of each available object


### Custom Extensions
- [count_workitems_by_type.js](count_workitems_by_type.js) - a helper to count the number of work items of a given type
- [each_with_sort_by_field.js](each_with_sort_by_field.js) - a helper to sort an array of WI based on a field name
- [get_only_message_firstline.js](get_only_message_firstline.js) - a helper to get just the first line of a multi-line string. Useful if you only want the title from a multi-line commit message
- [get_unique_projects.js](get_unique_projects.js) - a helper to extra the project name from a full file path only listing unique projects. This is a very rough implementation, but should act as a sample
- [GitFlow](gitflow-readme.md) - a template and helper to assist in report generation when using GitFlow
- [replace_text.js](replace_text.js) - a helper to replace some text value with another
- [return_parents_only.js](return_parents_only.js) - a helper to list just the parents of associated workitems
- [lookup_PR_by_LastCommitId](lookup_PR_by_LastCommitId) - a helper to lookup a PR from an array based on it's last commit Id
- [date_formatter](date_formatter) - a helper to convert a date to the current locality value
