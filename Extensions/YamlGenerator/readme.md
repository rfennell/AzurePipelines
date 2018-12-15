This set of tasks generate YAML documentation

## Generate YAML Documentation

The YAML documenter task uses the task.json files within an extension package to build YAML documentation. It is assumed that the file generated will be uploaded to some central location, such as a WIKI

### Usage

Add the task to a build or release

#### Required Parameters
- Source Directory - The root of the extension source, where the vss-extension.json file is
- Output Directory - Where to write the output markdown file to.

#### Optional Advanced Parameters
- FilePrefix - The output filename prefix, if not set the extension ID will be used from the vss-extension.json file

## Releases

- 1.0 Initial release
