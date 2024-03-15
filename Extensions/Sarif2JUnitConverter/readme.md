# Convert SARIF to JUNIT

This action converts SARIF files as exported by the Bicep command

```
az bicep lint -f azuredeploy.bicep --diagnostics-format sarif
```

to JUNIT format. 

## Usage
- sarifFile - the source SARIF file
- junitFile - the output JUNIT file


