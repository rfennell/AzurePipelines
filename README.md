# Azure DevOps Pipelines Extensions Repo

This repo contains Azure DevOps Services (VSTS) & Server (TFS) Pipeline Extensions. It has evolved over time

- Initially it contained PowerShell scripts to perform build tasks
- Next I moved these scripts into VSTS/TFS Build tasks to wrapper PowerShell scripts. 
- Finally the tasks have been placed in VSTS/TFS extensions for ease of installation. Any remaining PowerShell scripts have been moved to [this repo](https://github.com/rfennell/VSTSPowershell) 

## Under Active Support
Extension | Public Deployment Status
----------|------------------
Artifact PR Description | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/ArtifactDescription?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=79) 
Build Utils | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/Extensions/BuildUpdatingExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=70)
DevTest Labs |  [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/Extensions/DevtestLabsExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=63) 
FileCopier Utils |[![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/Extensions/FileCopyExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=69)  
GenerateReleaseNotes (XPlat) |[![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/Extensions/XplatGenerateReleaseNotes?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=85)
Manifest Versioning | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/Extensions/VersioningExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=65) 
WIKI Updater | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/extensions/WikiUpdaterExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=64)
WIKI PDF Exporter | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/extensions/WikiPDFExportExtension?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=92)
YAML Generator | [![Release Status](https://dev.azure.com/richardfennell/github/_apis/build/status/extensions/YamlGenerator?branchName=main&stageName=Documentation)](https://dev.azure.com/richardfennell/github/_build/latest?definitionId=83)

## Not supported as deprecated
Extension | Public Deployment Status
----------|------------------
GenerateReleaseNotes (PowerShell) | [![Release Status - GenerateReleaseNotes Extension (PowerShell)](https://richardfennell.vsrm.visualstudio.com/_apis/public/Release/badge/670b3a60-2021-47ab-a88b-d76ebd888a2f/3/5)](https://richardfennell.visualstudio.com/GitHub/GitHub%20Team/_releases2?definitionId=3&view=mine&_a=releases)
Pester | [![Release Status - Pester Extension](https://richardfennell.vsrm.visualstudio.com/_apis/public/Release/badge/670b3a60-2021-47ab-a88b-d76ebd888a2f/8/14)](https://richardfennell.visualstudio.com/GitHub/GitHub%20Team/_releases2?definitionId=8&view=mine&_a=releases)  
StyleCop  | [![Release Status - StyleCop Extension](https://richardfennell.vsrm.visualstudio.com/_apis/public/Release/badge/670b3a60-2021-47ab-a88b-d76ebd888a2f/7/12)](https://richardfennell.visualstudio.com/GitHub/GitHub%20Team/_releases2?definitionId=7&view=mine&_a=releases)
Typemock Runner  | [![Release Status - Typemock Runner Extension](https://richardfennell.vsrm.visualstudio.com/_apis/public/Release/badge/670b3a60-2021-47ab-a88b-d76ebd888a2f/5/8)](https://richardfennell.visualstudio.com/GitHub/GitHub%20Team/_releases2?definitionId=5&view=mine&_a=releases)

## Building Extensions ##

For details of how to build and deploy these tasks/extensions see [this repo's wiki](https://github.com/rfennell/AzurePipelines/wiki)

## Included Extensions in the Repo 
For more details of how to use these tasks see [this repo's wiki](https://github.com/rfennell/AzurePipelines/wiki)

