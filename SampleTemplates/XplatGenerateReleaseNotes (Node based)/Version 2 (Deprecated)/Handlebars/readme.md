# Sample Handlebar Templates and Custom Handlebars Extensions
This folder contains sample Handlebar Templates and custom Handlebars extensions for my [Cross Platform Release Notes Azure DevOps Task](https://github.com/rfennell/AzurePipelines/wiki/GenerateReleaseNotes---Node-based-Cross-Platform-Task)

## Templates
The provided .MD templates will provide basic reports outputed as markdown.

If you wish to output a different format alter the file extension and tag appropriately

## Extensions
The extensions are small block of Javascript that can be injected into the Handlebars processing to perform special function.

They are injected using the `customHandlebarsExtensionCode` parameter.

Each sample .JS file contains a single custom module, with a usage sample. if you wish to use multiple custom modules they can be combined into a single block e.g.

```
module.exports = {
    count_workitems_by_type: function (array, typeName) {
        return array.filter(wi => wi.fields['System.WorkItemType'] === typeName).length;
    };
    replace_text: function (msg, match, replacement) {
        return msg.replace(match, replacement);
    };
};
```

