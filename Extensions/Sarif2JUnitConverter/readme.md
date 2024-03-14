This set of tasks generate YAML documentation

## Generate YAML Documentation

The YAML documenter task uses the **task.json** files within an extension package to build YAML documentation. It can also copy the extensions readme.md to the same output location as the generated YAML file. The file name formats would be

- fileprefix-YAML.md
- fileprefix.md

It is assumed that the file generated will be uploaded to some location, such as a WIKI, by another task.

### Usage

Add the task to a build or release

#### Required Parameters
- Source Directory - The root of the extension source, where the vss-extension.json file is
- Output Directory - Where to write the output markdown file to.

#### Optional Advanced Parameters
- FilePrefix - The output filename prefix, if not set the extension ID will be used from the **vss-extension.json** file
- CopyReadme - If true will also copy the **readme.md** for the extension with the same file prefix as the YAML


